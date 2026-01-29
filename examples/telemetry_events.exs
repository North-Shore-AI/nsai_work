# examples/telemetry_events.exs
#
# Demonstrates attaching telemetry handlers and observing
# job lifecycle events in real time.
#
# Run: mix run examples/telemetry_events.exs

alias NsaiWork.Job

IO.puts("=== NsaiWork: Telemetry Events Example ===\n")

# Attach handlers for key job lifecycle events
:telemetry.attach_many(
  "example-lifecycle",
  [
    [:nsai_work, :job, :submitted],
    [:nsai_work, :job, :queued],
    [:nsai_work, :job, :started],
    [:nsai_work, :job, :completed]
  ],
  fn event, measurements, metadata, _config ->
    event_name = event |> Enum.map_join(".", &to_string/1)
    IO.puts("  [telemetry] #{event_name}")
    IO.puts("    measurements: #{inspect(measurements)}")
    IO.puts("    job_id: #{metadata[:job_id]}")
    IO.puts("    tenant: #{metadata[:tenant_id]}")

    if metadata[:status], do: IO.puts("    status: #{metadata[:status]}")
    if metadata[:backend], do: IO.puts("    backend: #{metadata[:backend]}")
    if measurements[:duration_ms], do: IO.puts("    duration: #{measurements[:duration_ms]}ms")

    IO.puts("")
  end,
  nil
)

# Attach a scheduler event handler
:telemetry.attach_many(
  "example-scheduler",
  [
    [:nsai_work, :scheduler, :admit],
    [:nsai_work, :scheduler, :select_backend]
  ],
  fn event, _measurements, metadata, _config ->
    event_name = event |> Enum.map_join(".", &to_string/1)

    IO.puts(
      "  [scheduler] #{event_name} -> #{inspect(Map.drop(metadata, [:job_id, :tenant_id]))}"
    )
  end,
  nil
)

# Attach queue event handler
:telemetry.attach_many(
  "example-queue",
  [
    [:nsai_work, :queue, :enqueue],
    [:nsai_work, :queue, :dequeue]
  ],
  fn event, _measurements, metadata, _config ->
    event_name = event |> Enum.map_join(".", &to_string/1)
    IO.puts("  [queue] #{event_name} queue=#{metadata[:queue]} priority=#{metadata[:priority]}")
  end,
  nil
)

IO.puts("Handlers attached. Submitting a job...\n")

# Submit a job and watch the events fire
job =
  Job.new(
    kind: :tool_call,
    tenant_id: "acme",
    namespace: "default",
    priority: :interactive,
    payload: %{tool: "echo", args: ["telemetry-demo"]}
  )

{:ok, _submitted} = NsaiWork.submit(job)

# Wait for async execution
Process.sleep(200)

IO.puts("---")
IO.puts("All events above were emitted during the lifecycle of a single job.")

# Clean up handlers
:telemetry.detach("example-lifecycle")
:telemetry.detach("example-scheduler")
:telemetry.detach("example-queue")

IO.puts("\n=== Done ===")
