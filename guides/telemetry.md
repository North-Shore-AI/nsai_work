# Telemetry

NsaiWork emits telemetry events at every stage of the job lifecycle. This guide covers the event reference, built-in handlers, and writing custom handlers.

## Quick Start

Attach the built-in console logger to see all events:

```elixir
NsaiWork.Telemetry.attach_console_logger()
```

This logs every event to the console — useful for development and debugging.

## Event Reference

### Job Lifecycle

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:nsai_work, :job, :submitted]` | `%{count: 1}` | `job_id`, `tenant_id`, `kind`, `priority` |
| `[:nsai_work, :job, :queued]` | `%{count: 1}` | `job_id`, `tenant_id`, `queue`, `priority` |
| `[:nsai_work, :job, :started]` | `%{count: 1}` | `job_id`, `tenant_id`, `backend`, `worker_id`, `attempt` |
| `[:nsai_work, :job, :completed]` | `%{count: 1, duration_ms: integer}` | `job_id`, `tenant_id`, `status`, `backend`, `attempt` |
| `[:nsai_work, :job, :canceled]` | `%{count: 1}` | `job_id`, `tenant_id` |
| `[:nsai_work, :job, :retry]` | `%{count: 1, delay_ms: integer}` | `job_id`, `tenant_id`, `attempt` |

### Scheduler

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:nsai_work, :scheduler, :admit]` | `%{count: 1}` | `job_id`, `tenant_id`, `decision` |
| `[:nsai_work, :scheduler, :select_backend]` | `%{count: 1}` | `job_id`, `tenant_id`, `backend` |

### Queue

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:nsai_work, :queue, :enqueue]` | `%{count: 1}` | `queue`, `job_id`, `priority` |
| `[:nsai_work, :queue, :dequeue]` | `%{count: 1}` | `queue`, `job_id` |
| `[:nsai_work, :queue, :overflow]` | `%{count: 1}` | `queue` |

## Custom Handlers

Attach a handler for specific events:

```elixir
:telemetry.attach(
  "my-job-metrics",
  [:nsai_work, :job, :completed],
  fn _event, measurements, metadata, _config ->
    IO.puts("""
    Job #{metadata.job_id} completed
      Status: #{metadata.status}
      Duration: #{measurements.duration_ms}ms
      Backend: #{metadata.backend}
    """)
  end,
  nil
)
```

### Handling Multiple Events

Use `:telemetry.attach_many/4` to handle several events with one handler:

```elixir
:telemetry.attach_many(
  "my-job-logger",
  [
    [:nsai_work, :job, :submitted],
    [:nsai_work, :job, :started],
    [:nsai_work, :job, :completed]
  ],
  fn event, measurements, metadata, _config ->
    event_name = event |> Enum.join(".")
    IO.puts("[#{event_name}] job=#{metadata.job_id} #{inspect(measurements)}")
  end,
  nil
)
```

## Metrics Collection

A typical production setup collects counters and histograms:

```elixir
defmodule MyApp.WorkMetrics do
  def setup do
    :telemetry.attach_many(
      "nsai-work-metrics",
      [
        [:nsai_work, :job, :submitted],
        [:nsai_work, :job, :completed],
        [:nsai_work, :job, :retry],
        [:nsai_work, :queue, :overflow]
      ],
      &handle_event/4,
      nil
    )
  end

  defp handle_event([:nsai_work, :job, :submitted], _measurements, metadata, _config) do
    # Increment counter by kind and priority
    :telemetry.execute(
      [:my_app, :jobs, :submitted],
      %{count: 1},
      %{kind: metadata.kind, priority: metadata.priority}
    )
  end

  defp handle_event([:nsai_work, :job, :completed], measurements, metadata, _config) do
    # Record duration histogram by backend
    :telemetry.execute(
      [:my_app, :jobs, :duration],
      %{milliseconds: measurements.duration_ms},
      %{backend: metadata.backend, status: metadata.status}
    )
  end

  defp handle_event([:nsai_work, :job, :retry], measurements, _metadata, _config) do
    # Track retry delays
    :telemetry.execute(
      [:my_app, :jobs, :retry_delay],
      %{milliseconds: measurements.delay_ms},
      %{}
    )
  end

  defp handle_event([:nsai_work, :queue, :overflow], _measurements, metadata, _config) do
    # Alert on queue overflow
    :telemetry.execute(
      [:my_app, :queue, :overflow],
      %{count: 1},
      %{queue: metadata.queue}
    )
  end
end
```

## Detaching Handlers

Remove a handler by its ID:

```elixir
:telemetry.detach("my-job-metrics")
```
