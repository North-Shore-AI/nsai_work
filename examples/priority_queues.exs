# examples/priority_queues.exs
#
# Demonstrates how jobs are routed to different priority queues
# and how queue statistics reflect the distribution.
#
# Run: mix run examples/priority_queues.exs

alias NsaiWork.Job

IO.puts("=== NsaiWork: Priority Queues Example ===\n")

priorities = [:realtime, :interactive, :batch, :offline]

# Submit one job at each priority level
submitted_jobs =
  for priority <- priorities do
    job =
      Job.new(
        kind: :tool_call,
        tenant_id: "acme",
        namespace: "default",
        priority: priority,
        payload: %{tool: "echo", args: ["priority: #{priority}"]}
      )

    {:ok, submitted} = NsaiWork.submit(job)
    IO.puts("Submitted #{priority} job: #{submitted.id}")
    submitted
  end

IO.puts("")

# Let jobs execute
Process.sleep(200)

# Check status of each job
IO.puts("Job statuses after execution:")

for job <- submitted_jobs do
  {:ok, result} = NsaiWork.get(job.id)
  IO.puts("  #{result.priority} -> #{result.status}")
end

IO.puts("")

# Show queue statistics
stats = NsaiWork.stats()
IO.puts("Queue sizes:")

for {queue_name, queue_stats} <- stats.scheduler.queues do
  IO.puts("  #{queue_name}: #{queue_stats.size} pending")
end

IO.puts("  Executing: #{stats.scheduler.executing}")
IO.puts("  Max concurrent: #{stats.scheduler.max_concurrent}")

# Submit a batch of jobs to show queuing behavior
IO.puts("\nSubmitting 5 batch jobs...")

for i <- 1..5 do
  job =
    Job.new(
      kind: :tool_call,
      tenant_id: "acme",
      namespace: "load-test",
      priority: :batch,
      payload: %{tool: "echo", args: ["batch-#{i}"]}
    )

  {:ok, _} = NsaiWork.submit(job)
end

Process.sleep(300)

# Show tenant job listing with namespace filter
batch_jobs = NsaiWork.list("acme", namespace: "load-test")
IO.puts("Jobs in 'load-test' namespace: #{length(batch_jobs)}")

for job <- batch_jobs do
  IO.puts("  #{job.id} -> #{job.status}")
end

IO.puts("\n=== Done ===")
