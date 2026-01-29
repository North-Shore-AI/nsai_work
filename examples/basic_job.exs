# examples/basic_job.exs
#
# Demonstrates basic job creation, submission, and status checking
# using the Local backend.
#
# Run: mix run examples/basic_job.exs

alias NsaiWork.{Job, Resources}

IO.puts("=== NsaiWork: Basic Job Example ===\n")

# Create a simple tool_call job
job =
  Job.new(
    kind: :tool_call,
    tenant_id: "acme",
    namespace: "default",
    priority: :interactive,
    payload: %{tool: "echo", args: ["hello", "world"]}
  )

IO.puts("Created job: #{job.id}")
IO.puts("  Kind:     #{job.kind}")
IO.puts("  Tenant:   #{job.tenant_id}")
IO.puts("  Priority: #{job.priority}")
IO.puts("  Status:   #{job.status}")
IO.puts("")

# Submit the job
{:ok, submitted} = NsaiWork.submit(job)
IO.puts("Submitted job: #{submitted.id}")
IO.puts("  Status after submit: #{submitted.status}")
IO.puts("")

# Allow async execution to complete
Process.sleep(100)

# Retrieve the job and check its status
{:ok, result} = NsaiWork.get(submitted.id)
IO.puts("Job result:")
IO.puts("  Status:  #{result.status}")
IO.puts("  Result:  #{inspect(result.result)}")
IO.puts("  Backend: #{inspect(result.backend)}")
IO.puts("")

# Create a job with resource requirements
job_with_resources =
  Job.new(
    kind: :tool_call,
    tenant_id: "acme",
    namespace: "default",
    priority: :batch,
    payload: %{tool: "compute", args: [1, 2, 3]},
    resources:
      Resources.new(
        cpu: 2.0,
        memory_mb: 1024,
        timeout_ms: 10_000
      )
  )

{:ok, submitted2} = NsaiWork.submit(job_with_resources)
Process.sleep(100)
{:ok, result2} = NsaiWork.get(submitted2.id)

IO.puts("Job with resources:")
IO.puts("  CPU:     #{result2.resources.cpu}")
IO.puts("  Memory:  #{result2.resources.memory_mb} MB")
IO.puts("  Status:  #{result2.status}")
IO.puts("")

# List all jobs for the tenant
jobs = NsaiWork.list("acme")
IO.puts("All jobs for tenant 'acme': #{length(jobs)}")

# Get stats
stats = NsaiWork.stats()
IO.puts("\nScheduler stats: #{inspect(stats.scheduler)}")
IO.puts("Registry stats:  #{inspect(stats.registry)}")

IO.puts("\n=== Done ===")
