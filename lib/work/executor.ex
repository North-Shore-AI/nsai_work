defmodule Work.Executor do
  @moduledoc """
  Job executor that delegates to backends.

  The Executor:
  1. Receives jobs from the scheduler
  2. Selects appropriate backend
  3. Executes the job
  4. Updates job status
  5. Handles retries on failure
  """

  use GenServer
  require Logger

  alias Work.{Backends, Constraints, Job, Registry, Telemetry}

  @default_backends [
    local: Backends.Local,
    mock: Backends.Mock
  ]

  ## Client API

  @doc """
  Starts the executor.

  ## Options

    * `:backends` - Map of backend name to module (default: local and mock)
    * `:name` - GenServer name
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Executes a job asynchronously.

  Returns immediately with `:ok`. Job status can be tracked
  via the Registry.

  ## Examples

      iex> Work.Executor.execute(job)
      :ok
  """
  @spec execute(Job.t()) :: :ok
  def execute(%Job{} = job) do
    GenServer.cast(__MODULE__, {:execute, job})
  end

  @doc """
  Executes a job synchronously and waits for result.

  ## Examples

      iex> Work.Executor.execute_sync(job)
      {:ok, %{result: "success"}}
  """
  @spec execute_sync(Job.t(), timeout()) :: {:ok, term()} | {:error, Work.Error.t()}
  def execute_sync(%Job{} = job, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:execute_sync, job}, timeout)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    backends = Keyword.get(opts, :backends, @default_backends) |> Map.new()

    state = %{
      backends: backends,
      executing: %{}
    }

    Logger.info("Work.Executor started with backends: #{inspect(Map.keys(backends))}")

    {:ok, state}
  end

  @impl true
  def handle_cast({:execute, job}, state) do
    # Execute in background task
    Task.start(fn ->
      do_execute(job, state.backends)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:execute_sync, job}, _from, state) do
    result = do_execute(job, state.backends)
    {:reply, result, state}
  end

  ## Private Execution Logic

  defp do_execute(job, backends) do
    Logger.debug("Executing job #{job.id} with kind #{job.kind}")

    # Select backend
    backend_module =
      case select_backend(job, backends) do
        {:ok, backend} ->
          Telemetry.scheduler_select_backend(job, backend)
          backend

        {:error, reason} ->
          Logger.error("Failed to select backend for job #{job.id}: #{inspect(reason)}")

          error =
            Work.Error.new(
              category: :backend,
              code: "NO_BACKEND",
              message: "No suitable backend available"
            )

          job = Job.mark_failed(job, error)
          Registry.put(job)
          Telemetry.job_completed(job)
          return({:error, error})
      end

    # Mark as running
    job = Job.mark_running(job, backend_name(backend_module), "executor-1")
    Registry.put(job)
    Telemetry.job_started(job)

    # Execute
    result =
      try do
        backend_module.execute(job)
      rescue
        exception ->
          Logger.error("Backend execution failed: #{inspect(exception)}")
          {:error, Work.Error.from_exception(exception)}
      end

    # Handle result
    case result do
      {:ok, value} ->
        job = Job.mark_succeeded(job, value)
        Registry.put(job)
        Telemetry.job_completed(job)
        {:ok, value}

      {:error, error} ->
        handle_failure(job, error)
    end
  end

  defp select_backend(job, backends) do
    # Filter backends that support this job
    suitable =
      backends
      |> Enum.filter(fn {_name, module} ->
        module.supports?(job)
      end)
      |> Enum.map(&elem(&1, 1))

    # Apply constraints
    suitable =
      case job.constraints do
        %Constraints{required_backends: [_ | _] = required} ->
          Enum.filter(suitable, fn module ->
            backend_name(module) in required
          end)

        %Constraints{excluded_backends: [_ | _] = excluded} ->
          Enum.reject(suitable, fn module ->
            backend_name(module) in excluded
          end)

        _ ->
          suitable
      end

    case suitable do
      [] -> {:error, :no_suitable_backend}
      [backend | _] -> {:ok, backend}
    end
  end

  defp handle_failure(job, error) do
    if error.retryable and Constraints.can_retry?(job.constraints, job.attempt) do
      # Schedule retry
      delay_ms = Constraints.retry_delay(job.constraints, job.attempt)
      job = Job.increment_attempt(job)
      Registry.put(job)
      Telemetry.job_retry(job, delay_ms)

      Logger.info("Retrying job #{job.id} after #{delay_ms}ms (attempt #{job.attempt})")

      # Schedule retry (in real implementation, use a queue with delay)
      Process.send_after(self(), {:retry, job}, delay_ms)

      {:error, error}
    else
      # Mark as failed
      job = Job.mark_failed(job, error)
      Registry.put(job)
      Telemetry.job_completed(job)
      {:error, error}
    end
  end

  @impl true
  def handle_info({:retry, job}, state) do
    # Re-execute the job
    Task.start(fn ->
      do_execute(job, state.backends)
    end)

    {:noreply, state}
  end

  defp backend_name(module) do
    module
    |> to_string()
    |> String.split(".")
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  defp return(value), do: throw({:return, value})
end
