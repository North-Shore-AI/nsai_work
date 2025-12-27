defmodule Work do
  @moduledoc """
  NSAI.Work - Unified job scheduler for the North-Shore-AI platform.

  Work provides a protocol-first, multi-tenant job scheduling system with:

  - **Unified Job IR**: Single representation for all work types
  - **Priority Queues**: realtime/interactive/batch/offline
  - **Resource-Aware Scheduling**: CPU, GPU, memory, cost-aware
  - **Pluggable Backends**: Local, ALTAR, Modal, Ray, etc.
  - **Telemetry Integration**: Full observability
  - **Retry Policies**: Configurable backoff per job

  ## Quick Start

      # Start the application
      {:ok, _} = Application.ensure_all_started(:work)

      # Submit a job
      job = Work.Job.new(
        kind: :tool_call,
        tenant_id: "acme",
        namespace: "default",
        priority: :interactive,
        payload: %{tool: "calculator", args: [2, 2]}
      )

      {:ok, submitted} = Work.submit(job)

      # Check job status
      {:ok, job} = Work.get(submitted.id)
      job.status  # => :running or :succeeded

      # Get queue statistics
      stats = Work.stats()

  ## Architecture

  Work consists of several components:

  - `Work.Job` - Universal job IR
  - `Work.Scheduler` - Priority queue management and admission control
  - `Work.Queue` - FIFO queues per priority level
  - `Work.Executor` - Job execution with backend delegation
  - `Work.Registry` - ETS-based job storage and indexing
  - `Work.Backend` - Pluggable execution backends
  - `Work.Telemetry` - Event instrumentation

  ## Multi-Tenancy

  All jobs are associated with a tenant and namespace:

      job = Work.Job.new(
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

  alias Work.{Job, Registry, Scheduler}

  @doc """
  Submits a job for execution.

  The job will be admitted to the scheduler, enqueued, and
  executed when resources are available.

  ## Examples

      iex> job = Work.Job.new(
      ...>   kind: :tool_call,
      ...>   tenant_id: "test",
      ...>   namespace: "default",
      ...>   payload: %{tool: "echo", args: ["hello"]}
      ...> )
      iex> {:ok, submitted} = Work.submit(job)
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

      iex> _jobs = Work.list("acme")
      iex> _filtered = Work.list("acme", status: :running)
  """
  @spec list(String.t(), keyword()) :: [Job.t()]
  def list(tenant_id, opts \\ []) do
    Registry.list_by_tenant(tenant_id, opts)
  end

  @doc """
  Returns combined statistics for the scheduler and registry.

  ## Examples

      iex> stats = Work.stats()
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
