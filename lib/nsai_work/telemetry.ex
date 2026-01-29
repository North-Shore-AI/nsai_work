defmodule NsaiWork.Telemetry do
  @moduledoc """
  Telemetry instrumentation for Work events.

  Emits events for job lifecycle, scheduling decisions,
  queue operations, and backend interactions.

  ## Events

  ### Job Lifecycle
  - `[:nsai_work, :job, :submitted]` - Job submitted
  - `[:nsai_work, :job, :queued]` - Job enqueued
  - `[:nsai_work, :job, :started]` - Job execution started
  - `[:nsai_work, :job, :completed]` - Job completed (success or failure)
  - `[:nsai_work, :job, :canceled]` - Job canceled
  - `[:nsai_work, :job, :retry]` - Job retry scheduled

  ### Scheduler
  - `[:nsai_work, :scheduler, :admit]` - Admission decision
  - `[:nsai_work, :scheduler, :select_backend]` - Backend selection

  ### Queue
  - `[:nsai_work, :queue, :enqueue]` - Job enqueued
  - `[:nsai_work, :queue, :dequeue]` - Job dequeued
  - `[:nsai_work, :queue, :overflow]` - Queue capacity exceeded

  ## Usage

      # Attach a handler
      :telemetry.attach(
        "nsai-work-logger",
        [:nsai_work, :job, :completed],
        &MyApp.handle_telemetry/4,
        nil
      )
  """

  require Logger

  @doc """
  Emits a job submitted event.
  """
  def job_submitted(job) do
    :telemetry.execute(
      [:nsai_work, :job, :submitted],
      %{count: 1},
      %{
        job_id: job.id,
        tenant_id: job.tenant_id,
        kind: job.kind,
        priority: job.priority
      }
    )
  end

  @doc """
  Emits a job queued event.
  """
  def job_queued(job, queue_name) do
    :telemetry.execute(
      [:nsai_work, :job, :queued],
      %{count: 1},
      %{
        job_id: job.id,
        tenant_id: job.tenant_id,
        queue: queue_name,
        priority: job.priority
      }
    )
  end

  @doc """
  Emits a job started event.
  """
  def job_started(job) do
    :telemetry.execute(
      [:nsai_work, :job, :started],
      %{count: 1},
      %{
        job_id: job.id,
        tenant_id: job.tenant_id,
        backend: job.backend,
        worker_id: job.worker_id,
        attempt: job.attempt
      }
    )
  end

  @doc """
  Emits a job completed event.
  """
  def job_completed(job) do
    duration_ms = NsaiWork.Job.duration_ms(job) || 0

    :telemetry.execute(
      [:nsai_work, :job, :completed],
      %{
        count: 1,
        duration_ms: duration_ms
      },
      %{
        job_id: job.id,
        tenant_id: job.tenant_id,
        status: job.status,
        backend: job.backend,
        attempt: job.attempt
      }
    )
  end

  @doc """
  Emits a job canceled event.
  """
  def job_canceled(job) do
    :telemetry.execute(
      [:nsai_work, :job, :canceled],
      %{count: 1},
      %{
        job_id: job.id,
        tenant_id: job.tenant_id
      }
    )
  end

  @doc """
  Emits a job retry event.
  """
  def job_retry(job, delay_ms) do
    :telemetry.execute(
      [:nsai_work, :job, :retry],
      %{
        count: 1,
        delay_ms: delay_ms
      },
      %{
        job_id: job.id,
        tenant_id: job.tenant_id,
        attempt: job.attempt
      }
    )
  end

  @doc """
  Emits a scheduler admission event.
  """
  def scheduler_admit(job, decision) do
    :telemetry.execute(
      [:nsai_work, :scheduler, :admit],
      %{count: 1},
      %{
        job_id: job.id,
        tenant_id: job.tenant_id,
        decision: decision
      }
    )
  end

  @doc """
  Emits a backend selection event.
  """
  def scheduler_select_backend(job, backend) do
    :telemetry.execute(
      [:nsai_work, :scheduler, :select_backend],
      %{count: 1},
      %{
        job_id: job.id,
        tenant_id: job.tenant_id,
        backend: backend
      }
    )
  end

  @doc """
  Emits a queue enqueue event.
  """
  def queue_enqueue(queue_name, job) do
    :telemetry.execute(
      [:nsai_work, :queue, :enqueue],
      %{count: 1},
      %{
        queue: queue_name,
        job_id: job.id,
        priority: job.priority
      }
    )
  end

  @doc """
  Emits a queue dequeue event.
  """
  def queue_dequeue(queue_name, job) do
    :telemetry.execute(
      [:nsai_work, :queue, :dequeue],
      %{count: 1},
      %{
        queue: queue_name,
        job_id: job.id
      }
    )
  end

  @doc """
  Emits a queue overflow event.
  """
  def queue_overflow(queue_name) do
    :telemetry.execute(
      [:nsai_work, :queue, :overflow],
      %{count: 1},
      %{queue: queue_name}
    )
  end

  @doc """
  Attaches a default console logger for all Work events.

  Useful for development and debugging.

  ## Examples

      NsaiWork.Telemetry.attach_console_logger()
  """
  def attach_console_logger do
    events = [
      [:nsai_work, :job, :submitted],
      [:nsai_work, :job, :queued],
      [:nsai_work, :job, :started],
      [:nsai_work, :job, :completed],
      [:nsai_work, :job, :canceled],
      [:nsai_work, :job, :retry],
      [:nsai_work, :scheduler, :admit],
      [:nsai_work, :scheduler, :select_backend],
      [:nsai_work, :queue, :enqueue],
      [:nsai_work, :queue, :dequeue],
      [:nsai_work, :queue, :overflow]
    ]

    :telemetry.attach_many(
      "nsai-work-console-logger",
      events,
      &handle_event/4,
      nil
    )
  end

  defp handle_event(event, measurements, metadata, _config) do
    Logger.info(
      "[NsaiWork.Telemetry] #{inspect(event)} - " <>
        "measurements: #{inspect(measurements)}, " <>
        "metadata: #{inspect(metadata)}"
    )
  end
end
