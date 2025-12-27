defmodule Work.Backends.Mock do
  @moduledoc """
  Mock backend for testing.

  This backend allows tests to control execution behavior:
  - Configure success/failure
  - Simulate delays
  - Track execution history
  - Simulate resource constraints

  ## Examples

      # Configure mock to succeed
      Work.Backends.Mock.configure(behavior: :succeed)

      # Configure mock to fail
      Work.Backends.Mock.configure(behavior: {:fail, "Something went wrong"})

      # Configure mock with delay
      Work.Backends.Mock.configure(delay_ms: 100)

      # Get execution history
      history = Work.Backends.Mock.history()
  """

  @behaviour Work.Backend

  alias Work.{Error, Job}

  use Agent

  @doc """
  Starts the mock backend agent.
  """
  def start_link(opts \\ []) do
    Agent.start_link(fn -> initial_state(opts) end, name: __MODULE__)
  end

  @doc """
  Configures the mock backend behavior.

  ## Options

    * `:behavior` - Either `:succeed`, `{:fail, message}`, or a function
    * `:delay_ms` - Delay before returning result (default: 0)
    * `:supports` - List of job kinds to support (default: all)
  """
  def configure(opts) do
    if Process.whereis(__MODULE__) == nil do
      start_link(opts)
    else
      Agent.update(__MODULE__, fn state ->
        Map.merge(state, Map.new(opts))
      end)
    end
  end

  @doc """
  Returns the execution history.
  """
  def history do
    if Process.whereis(__MODULE__) do
      Agent.get(__MODULE__, & &1.history)
    else
      []
    end
  end

  @doc """
  Resets the mock backend state.
  """
  def reset do
    if Process.whereis(__MODULE__) do
      Agent.update(__MODULE__, fn _ -> initial_state() end)
    end
  end

  @impl true
  def execute(%Job{} = job) do
    if Process.whereis(__MODULE__) == nil do
      start_link()
    end

    state = Agent.get(__MODULE__, & &1)

    # Record execution
    Agent.update(__MODULE__, fn state ->
      %{state | history: [job | state.history]}
    end)

    # Simulate delay
    if state.delay_ms > 0 do
      Process.sleep(state.delay_ms)
    end

    # Execute based on configured behavior
    case state.behavior do
      :succeed ->
        {:ok, %{job_id: job.id, result: "mocked success"}}

      {:fail, message} ->
        {:error,
         Error.new(
           category: :backend,
           code: "MOCK_FAILURE",
           message: message
         )}

      fun when is_function(fun, 1) ->
        fun.(job)

      _ ->
        {:ok, %{job_id: job.id, result: "mocked success"}}
    end
  end

  @impl true
  def cancel(job_id) do
    if Process.whereis(__MODULE__) do
      Agent.update(__MODULE__, fn state ->
        %{state | canceled: [job_id | state.canceled]}
      end)
    end

    :ok
  end

  @impl true
  def status(job_id) do
    {:ok, %{job_id: job_id, status: "mock_status"}}
  end

  @impl true
  def supports?(%Job{kind: kind}) do
    if Process.whereis(__MODULE__) do
      state = Agent.get(__MODULE__, & &1)

      case state.supports do
        :all -> true
        kinds when is_list(kinds) -> kind in kinds
        _ -> true
      end
    else
      true
    end
  end

  defp initial_state(opts \\ []) do
    %{
      behavior: opts[:behavior] || :succeed,
      delay_ms: opts[:delay_ms] || 0,
      supports: opts[:supports] || :all,
      history: [],
      canceled: []
    }
  end
end
