defmodule NsaiWork do
  @moduledoc """
  NsaiWork - Unified job scheduler for the North-Shore-AI platform.

  NsaiWork provides a protocol-first, multi-tenant job scheduling system with:

  - **Unified Job IR**: Single representation for all work types
  - **Priority Queues**: realtime/interactive/batch/offline
  - **Resource-Aware Scheduling**: CPU, GPU, memory, cost-aware
  - **Pluggable Backends**: Local, ALTAR, Modal, Ray, etc.
  - **Telemetry Integration**: Full observability
  - **Retry Policies**: Configurable backoff per job

  ## Quick Start

      # Start the application
      {:ok, _} = Application.ensure_all_started(:nsai_work)

      # Submit a job
      job = NsaiWork.Job.new(
        kind: :tool_call,
        tenant_id: "acme",
        namespace: "default",
        priority: :interactive,
        payload: %{tool: "calculator", args: [2, 2]}
      )

      {:ok, submitted} = NsaiWork.submit(job)

      # Check job status
      {:ok, job} = NsaiWork.get(submitted.id)
      job.status  # => :running or :succeeded

      # Get queue statistics
      stats = NsaiWork.stats()

  ## Architecture

  NsaiWork consists of several components:

  - `NsaiWork.Job` - Universal job IR
  - `NsaiWork.Scheduler` - Priority queue management and admission control
  - `NsaiWork.Queue` - FIFO queues per priority level
  - `NsaiWork.Executor` - Job execution with backend delegation
  - `NsaiWork.Registry` - ETS-based job storage and indexing
  - `NsaiWork.Backend` - Pluggable execution backends
  - `NsaiWork.Telemetry` - Event instrumentation

  ## Multi-Tenancy

  All jobs are associated with a tenant and namespace:

      job = NsaiWork.Job.new(
        tenant_id: "customer-123",
        namespace: "production",
        # ... other fields
      )

  This enables:
  - Quota enforcement per tenant
  - Fairness across tenants
  - Isolation of workloads

  ## Job Lifecycle

  ```
  pending -> queued -> running -> {succeeded | failed | canceled | timeout}
                                         ↓
                                    (retry) -> queued
  ```

  Jobs move through states as they're processed:
  1. **pending** - Just created
  2. **queued** - Waiting in priority queue
  3. **running** - Executing on backend
  4. **succeeded/failed/canceled/timeout** - Terminal states

  Failed jobs may be retried based on their constraints.
  """

  alias NsaiWork.{Job, Registry, Scheduler}

  @doc """
  Submits a job for execution.

  The job will be admitted to the scheduler, enqueued, and
  executed when resources are available.

  ## Examples

      iex> job = NsaiWork.Job.new(
      ...>   kind: :tool_call,
      ...>   tenant_id: "test",
      ...>   namespace: "default",
      ...>   payload: %{tool: "echo", args: ["hello"]}
      ...> )
      iex> {:ok, submitted} = NsaiWork.submit(job)
      iex> submitted.status
      :queued
  """
  @spec submit(Job.t()) :: {:ok, Job.t()} | {:error, term()}
  def submit(%Job{} = job) do
    Scheduler.submit(job)
  end

  @doc """
  Gets a job by ID.

  Returns `{:ok, job}` if found, `{:error, :not_found}` otherwise.
  """
  @spec get(String.t()) :: {:ok, Job.t()} | {:error, :not_found}
  def get(job_id) do
    Registry.get(job_id)
  end

  @doc """
  Lists jobs for a tenant.

  ## Options

    * `:namespace` - Filter by namespace
    * `:status` - Filter by status
    * `:limit` - Limit results (default: 100)

  ## Examples

      iex> _jobs = NsaiWork.list("acme")
      iex> _filtered = NsaiWork.list("acme", status: :running)
  """
  @spec list(String.t(), keyword()) :: [Job.t()]
  def list(tenant_id, opts \\ []) do
    Registry.list_by_tenant(tenant_id, opts)
  end

  @doc """
  Returns combined statistics for the scheduler and registry.

  ## Examples

      iex> stats = NsaiWork.stats()
      iex> Map.has_key?(stats, :scheduler)
      true
      iex> Map.has_key?(stats, :registry)
      true
  """
  @spec stats() :: map()
  def stats do
    %{
      scheduler: Scheduler.stats(),
      registry: Registry.stats()
    }
  end

  @doc """
  Cancels a job (not yet implemented).
  """
  @spec cancel(String.t()) :: :ok | {:error, term()}
  def cancel(_job_id) do
    {:error, :not_implemented}
  end
end
