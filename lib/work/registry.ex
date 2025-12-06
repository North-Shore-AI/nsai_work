defmodule Work.Registry do
  @moduledoc """
  ETS-based job registry for fast lookups.

  Provides in-memory storage and indexing of jobs with:
  - Primary key: job_id
  - Indexes: tenant_id, namespace, status, backend

  For production deployments, consider backing this with
  a persistent store (Postgres, etc.) via a behaviour.
  """

  use GenServer
  require Logger

  alias Work.Job

  @table :work_registry
  @tenant_index :work_registry_tenant_index
  @status_index :work_registry_status_index

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Inserts or updates a job in the registry.

  ## Examples

      iex> Work.Registry.put(job)
      :ok
  """
  @spec put(Job.t()) :: :ok
  def put(%Job{} = job) do
    GenServer.call(__MODULE__, {:put, job})
  end

  @doc """
  Gets a job by ID.

  ## Examples

      iex> Work.Registry.get("job-123")
      {:ok, %Work.Job{}}

      iex> Work.Registry.get("nonexistent")
      {:error, :not_found}
  """
  @spec get(String.t()) :: {:ok, Job.t()} | {:error, :not_found}
  def get(job_id) do
    case :ets.lookup(@table, job_id) do
      [{^job_id, job}] -> {:ok, job}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Deletes a job from the registry.

  ## Examples

      iex> Work.Registry.delete("job-123")
      :ok
  """
  @spec delete(String.t()) :: :ok
  def delete(job_id) do
    GenServer.call(__MODULE__, {:delete, job_id})
  end

  @doc """
  Lists all jobs for a tenant.

  ## Options

    * `:namespace` - Filter by namespace
    * `:status` - Filter by status
    * `:limit` - Limit results (default: 100)

  ## Examples

      iex> Work.Registry.list_by_tenant("acme")
      [%Work.Job{}, ...]

      iex> Work.Registry.list_by_tenant("acme", status: :running)
      [%Work.Job{}, ...]
  """
  @spec list_by_tenant(String.t(), keyword()) :: [Job.t()]
  def list_by_tenant(tenant_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    jobs =
      case :ets.lookup(@tenant_index, tenant_id) do
        [{^tenant_id, job_ids}] ->
          job_ids
          |> Enum.take(limit)
          |> Enum.map(&get/1)
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, job} -> job end)

        [] ->
          []
      end

    # Apply filters
    jobs
    |> filter_by_namespace(opts[:namespace])
    |> filter_by_status(opts[:status])
  end

  @doc """
  Lists jobs by status.

  ## Examples

      iex> Work.Registry.list_by_status(:running)
      [%Work.Job{}, ...]
  """
  @spec list_by_status(Job.status()) :: [Job.t()]
  def list_by_status(status) do
    case :ets.lookup(@status_index, status) do
      [{^status, job_ids}] ->
        job_ids
        |> Enum.map(&get/1)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, job} -> job end)

      [] ->
        []
    end
  end

  @doc """
  Returns registry statistics.

  ## Examples

      iex> Work.Registry.stats()
      %{
        total: 150,
        by_status: %{pending: 10, running: 5, succeeded: 135},
        by_tenant: %{"acme" => 100, "other" => 50}
      }
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@tenant_index, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@status_index, [:named_table, :set, :public, read_concurrency: true])

    Logger.info("Work.Registry started")

    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, job}, _from, state) do
    # Store job
    :ets.insert(@table, {job.id, job})

    # Update tenant index
    update_tenant_index(job)

    # Update status index
    update_status_index(job)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, job_id}, _from, state) do
    case get(job_id) do
      {:ok, job} ->
        # Remove from main table
        :ets.delete(@table, job_id)

        # Remove from indexes
        remove_from_tenant_index(job)
        remove_from_status_index(job)

        {:reply, :ok, state}

      {:error, :not_found} ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    total = :ets.info(@table, :size)

    by_status =
      :ets.tab2list(@status_index)
      |> Enum.map(fn {status, job_ids} -> {status, length(job_ids)} end)
      |> Map.new()

    by_tenant =
      :ets.tab2list(@tenant_index)
      |> Enum.map(fn {tenant_id, job_ids} -> {tenant_id, length(job_ids)} end)
      |> Map.new()

    stats = %{
      total: total,
      by_status: by_status,
      by_tenant: by_tenant
    }

    {:reply, stats, state}
  end

  ## Private Helpers

  defp update_tenant_index(%Job{tenant_id: tenant_id, id: job_id}) do
    job_ids =
      case :ets.lookup(@tenant_index, tenant_id) do
        [{^tenant_id, existing}] -> [job_id | existing] |> Enum.uniq()
        [] -> [job_id]
      end

    :ets.insert(@tenant_index, {tenant_id, job_ids})
  end

  defp remove_from_tenant_index(%Job{tenant_id: tenant_id, id: job_id}) do
    case :ets.lookup(@tenant_index, tenant_id) do
      [{^tenant_id, job_ids}] ->
        updated = List.delete(job_ids, job_id)
        :ets.insert(@tenant_index, {tenant_id, updated})

      [] ->
        :ok
    end
  end

  defp update_status_index(%Job{status: status, id: job_id}) do
    job_ids =
      case :ets.lookup(@status_index, status) do
        [{^status, existing}] -> [job_id | existing] |> Enum.uniq()
        [] -> [job_id]
      end

    :ets.insert(@status_index, {status, job_ids})
  end

  defp remove_from_status_index(%Job{status: status, id: job_id}) do
    case :ets.lookup(@status_index, status) do
      [{^status, job_ids}] ->
        updated = List.delete(job_ids, job_id)
        :ets.insert(@status_index, {status, updated})

      [] ->
        :ok
    end
  end

  defp filter_by_namespace(jobs, nil), do: jobs

  defp filter_by_namespace(jobs, namespace) do
    Enum.filter(jobs, &(&1.namespace == namespace))
  end

  defp filter_by_status(jobs, nil), do: jobs

  defp filter_by_status(jobs, status) do
    Enum.filter(jobs, &(&1.status == status))
  end
end
