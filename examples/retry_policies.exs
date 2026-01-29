# examples/retry_policies.exs
#
# Demonstrates retry policy configuration and backoff calculation.
#
# Run: mix run examples/retry_policies.exs

alias NsaiWork.{Job, Constraints}

IO.puts("=== NsaiWork: Retry Policies Example ===\n")

# --- Backoff Strategy Comparison ---

IO.puts("Backoff delay comparison (base_delay: 1000ms, max_delay: 60000ms):\n")

strategies = [:exponential, :linear, :constant]

for strategy <- strategies do
  constraints =
    Constraints.new(
      retry_policy: %{
        max_attempts: 6,
        backoff: strategy,
        base_delay_ms: 1000,
        max_delay_ms: 60_000,
        jitter: false
      }
    )

  delays =
    for attempt <- 1..5 do
      Constraints.retry_delay(constraints, attempt)
    end

  IO.puts("  #{strategy}:")
  IO.puts("    Attempts 1-5: #{inspect(delays)} ms")
  IO.puts("    Can retry at attempt 5? #{Constraints.can_retry?(constraints, 5)}")
  IO.puts("    Can retry at attempt 6? #{Constraints.can_retry?(constraints, 6)}")
  IO.puts("")
end

# --- Jitter ---

IO.puts("Effect of jitter (exponential, 10 samples at attempt 3):\n")

constraints_no_jitter =
  Constraints.new(
    retry_policy: %{
      max_attempts: 5,
      backoff: :exponential,
      base_delay_ms: 1000,
      max_delay_ms: 60_000,
      jitter: false
    }
  )

constraints_jitter =
  Constraints.new(
    retry_policy: %{
      max_attempts: 5,
      backoff: :exponential,
      base_delay_ms: 1000,
      max_delay_ms: 60_000,
      jitter: true
    }
  )

no_jitter_delays = for _ <- 1..10, do: Constraints.retry_delay(constraints_no_jitter, 3)
jitter_delays = for _ <- 1..10, do: Constraints.retry_delay(constraints_jitter, 3)

IO.puts("  Without jitter: #{inspect(Enum.uniq(no_jitter_delays))}")
IO.puts("  With jitter:    #{inspect(jitter_delays)}")
IO.puts("")

# --- Job with Retry Constraints ---

IO.puts("Submitting a job with custom retry policy:")

job =
  Job.new(
    kind: :tool_call,
    tenant_id: "acme",
    namespace: "default",
    priority: :batch,
    payload: %{tool: "echo", args: ["retry-demo"]},
    constraints:
      Constraints.new(
        retry_policy: %{
          max_attempts: 3,
          backoff: :exponential,
          base_delay_ms: 500,
          max_delay_ms: 10_000,
          jitter: true
        }
      )
  )

IO.puts("  Max attempts: #{job.constraints.retry_policy.max_attempts}")
IO.puts("  Backoff:      #{job.constraints.retry_policy.backoff}")
IO.puts("  Base delay:   #{job.constraints.retry_policy.base_delay_ms}ms")
IO.puts("")

{:ok, submitted} = NsaiWork.submit(job)
Process.sleep(100)
{:ok, result} = NsaiWork.get(submitted.id)
IO.puts("  Status:   #{result.status}")
IO.puts("  Attempts: #{result.attempt}")

IO.puts("\n=== Done ===")
