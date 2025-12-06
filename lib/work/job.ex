defmodule Work.Job do
  @moduledoc """
  Universal job IR representing any unit of work across the NSAI platform.

  Jobs can wrap:
  - Tool calls (ALTAR, LATER, GRID)
  - Experiment steps (Crucible)
  - Workflow steps (Synapse)
  - Training operations (Forge, Anvil)
  - Inference requests
  - Backend commands

  ## Multi-tenancy

  All jobs are associated with a tenant and namespace, enabling:
  - Quota enforcement per tenant
  - Fairness across tenants
  - Isolation of workloads

  ## Status Lifecycle

  ```
  pending -> queued -> running -> {succeeded | failed | canceled | timeout}
  ```

  Jobs can be retried based on their constraints, moving back to `queued`.
  """

  alias Work.{Resources, Constraints, Error}

  @type priority :: :realtime | :interactive | :batch | :offline

  @type status ::
          :pending
          | :queued
          | :running
          | :succeeded
          | :failed
          | :canceled
          | :timeout

  @type kind ::
          :tool_call
          | :experiment_step
          | :workflow_step
          | :training_step
          | :inference
          | :backend_command
          | :composite

  @type t :: %__MODULE__{
          id: String.t(),
          parent_id: String.t() | nil,
          tenant_id: String.t(),
          namespace: String.t(),
          owner: String.t() | nil,
          kind: kind(),
          priority: priority(),
          tags: [atom()],
          payload: map(),
          resources: Resources.t(),
          constraints: Constraints.t(),
          status: status(),
          created_at: DateTime.t(),
          queued_at: DateTime.t() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          backend: atom() | nil,
          worker_id: String.t() | nil,
          attempt: non_neg_integer(),
          result: term() | nil,
          error: Error.t() | nil,
          trace_id: String.t(),
          span_id: String.t() | nil,
          metadata: map()
        }

  defstruct [
    :id,
    :parent_id,
    :tenant_id,
    :namespace,
    :owner,
    :kind,
    :payload,
    :created_at,
    :queued_at,
    :started_at,
    :completed_at,
    :backend,
    :worker_id,
    :result,
    :error,
    :trace_id,
    :span_id,
    priority: :batch,
    tags: [],
    resources: %Resources{},
    constraints: %Constraints{},
    status: :pending,
    attempt: 0,
    metadata: %{}
  ]

  @doc """
  Creates a new job with the given attributes.

  Automatically generates ID and trace_id if not provided.

  ## Examples

      iex> job = Work.Job.new(
      ...>   kind: :tool_call,
      ...>   tenant_id: "acme",
      ...>   namespace: "default",
      ...>   payload: %{tool: "calculator", args: [2, 2]}
      ...> )
      iex> job.status
      :pending
      iex> job.priority
      :batch
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    now = DateTime.utc_now()

    opts =
      opts
      |> Keyword.put_new(:id, generate_id())
      |> Keyword.put_new(:trace_id, generate_trace_id())
      |> Keyword.put_new(:created_at, now)

    # Handle nested structs
    opts =
      opts
      |> update_if_present(:resources, &ensure_struct(&1, Resources))
      |> update_if_present(:constraints, &ensure_struct(&1, Constraints))

    struct(__MODULE__, opts)
  end

  @doc """
  Marks the job as queued at the current time.

  ## Examples

      iex> job = Work.Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      iex> queued = Work.Job.mark_queued(job)
      iex> queued.status
      :queued
  """
  @spec mark_queued(t()) :: t()
  def mark_queued(%__MODULE__{} = job) do
    %{job | status: :queued, queued_at: DateTime.utc_now()}
  end

  @doc """
  Marks the job as running with the given backend and worker.

  ## Examples

      iex> job = Work.Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      iex> running = Work.Job.mark_running(job, :local, "worker-1")
      iex> running.status
      :running
      iex> running.backend
      :local
  """
  @spec mark_running(t(), atom(), String.t()) :: t()
  def mark_running(%__MODULE__{} = job, backend, worker_id) do
    %{
      job
      | status: :running,
        backend: backend,
        worker_id: worker_id,
        started_at: DateTime.utc_now()
    }
  end

  @doc """
  Marks the job as succeeded with the given result.

  ## Examples

      iex> job = Work.Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      iex> succeeded = Work.Job.mark_succeeded(job, %{answer: 42})
      iex> succeeded.status
      :succeeded
      iex> succeeded.result
      %{answer: 42}
  """
  @spec mark_succeeded(t(), term()) :: t()
  def mark_succeeded(%__MODULE__{} = job, result) do
    %{job | status: :succeeded, result: result, completed_at: DateTime.utc_now()}
  end

  @doc """
  Marks the job as failed with the given error.

  ## Examples

      iex> job = Work.Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      iex> error = Work.Error.new(category: :timeout, code: "TIMEOUT", message: "Job timed out")
      iex> failed = Work.Job.mark_failed(job, error)
      iex> failed.status
      :failed
  """
  @spec mark_failed(t(), Error.t()) :: t()
  def mark_failed(%__MODULE__{} = job, %Error{} = error) do
    %{job | status: :failed, error: error, completed_at: DateTime.utc_now()}
  end

  @doc """
  Marks the job as canceled.

  ## Examples

      iex> job = Work.Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      iex> canceled = Work.Job.mark_canceled(job)
      iex> canceled.status
      :canceled
  """
  @spec mark_canceled(t()) :: t()
  def mark_canceled(%__MODULE__{} = job) do
    error =
      Error.new(
        category: :canceled,
        code: "CANCELED",
        message: "Job was canceled",
        retryable: false
      )

    %{job | status: :canceled, error: error, completed_at: DateTime.utc_now()}
  end

  @doc """
  Increments the job's attempt counter for retry.

  ## Examples

      iex> job = Work.Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      iex> retried = Work.Job.increment_attempt(job)
      iex> retried.attempt
      1
  """
  @spec increment_attempt(t()) :: t()
  def increment_attempt(%__MODULE__{} = job) do
    %{job | attempt: job.attempt + 1, status: :pending}
  end

  @doc """
  Returns true if the job is in a terminal state.

  ## Examples

      iex> job = Work.Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      iex> Work.Job.terminal?(job)
      false

      iex> job2 = Work.Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      iex> succeeded = Work.Job.mark_succeeded(job2, %{})
      iex> Work.Job.terminal?(succeeded)
      true
  """
  @spec terminal?(t()) :: boolean()
  def terminal?(%__MODULE__{status: status}) do
    status in [:succeeded, :failed, :canceled, :timeout]
  end

  @doc """
  Returns the duration of job execution in milliseconds.

  Returns nil if the job hasn't completed.

  ## Examples

      iex> job = Work.Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      iex> Work.Job.duration_ms(job)
      nil
  """
  @spec duration_ms(t()) :: non_neg_integer() | nil
  def duration_ms(%__MODULE__{started_at: nil}), do: nil
  def duration_ms(%__MODULE__{completed_at: nil}), do: nil

  def duration_ms(%__MODULE__{started_at: started, completed_at: completed}) do
    DateTime.diff(completed, started, :millisecond)
  end

  # Private helpers

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp ensure_struct(value, module) when is_struct(value, module), do: value
  defp ensure_struct(value, module) when is_map(value), do: struct(module, Map.to_list(value))
  defp ensure_struct(value, module) when is_list(value), do: struct(module, value)

  defp update_if_present(opts, key, fun) do
    if Keyword.has_key?(opts, key) do
      Keyword.update!(opts, key, fun)
    else
      opts
    end
  end
end
