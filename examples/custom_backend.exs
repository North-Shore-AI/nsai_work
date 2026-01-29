# examples/custom_backend.exs
#
# Demonstrates implementing and using a custom backend.
# Defines a simple logging backend inline and submits jobs to it.
#
# Run: mix run examples/custom_backend.exs

alias NsaiWork.Job

IO.puts("=== NsaiWork: Custom Backend Example ===\n")

# Define a custom backend that logs and echoes the payload
defmodule Examples.LoggingBackend do
  @behaviour NsaiWork.Backend

  require Logger

  @impl true
  def execute(%Job{} = job) do
    IO.puts("  [LoggingBackend] Executing job #{job.id}")
    IO.puts("  [LoggingBackend] Kind: #{job.kind}, Tenant: #{job.tenant_id}")
    IO.puts("  [LoggingBackend] Payload: #{inspect(job.payload)}")

    # Simulate work
    Process.sleep(50)

    {:ok,
     %{
       backend: :logging,
       processed_at: DateTime.utc_now(),
       echo: job.payload
     }}
  end

  @impl true
  def supports?(%Job{kind: kind}) do
    kind in [:inference, :training_step]
  end
end

# Start a new Executor with the custom backend alongside Local
# (The default Executor is already running; we start a separate one for demo)
{:ok, executor} =
  NsaiWork.Executor.start_link(
    name: :custom_executor,
    backends: %{
      local: NsaiWork.Backends.Local,
      logging: Examples.LoggingBackend
    }
  )

IO.puts("Started executor with backends: local, logging\n")

# Submit an inference job — should route to LoggingBackend
inference_job =
  Job.new(
    kind: :inference,
    tenant_id: "acme",
    namespace: "models",
    priority: :interactive,
    payload: %{model: "llama-3.1-8b", prompt: "Explain NsaiWork"}
  )

IO.puts("Submitting inference job (should use LoggingBackend):")
result = NsaiWork.Executor.execute_sync(inference_job)
IO.puts("  Result: #{inspect(result)}\n")

# Submit a tool_call job — should route to Local
tool_job =
  Job.new(
    kind: :tool_call,
    tenant_id: "acme",
    namespace: "default",
    payload: %{tool: "echo", args: ["hello"]}
  )

IO.puts("Submitting tool_call job (should use Local):")
result2 = NsaiWork.Executor.execute_sync(tool_job)
IO.puts("  Result: #{inspect(result2)}\n")

# Show that supports?/1 controls routing
IO.puts("Backend support check:")

IO.puts(
  "  LoggingBackend supports inference?  #{Examples.LoggingBackend.supports?(inference_job)}"
)

IO.puts("  LoggingBackend supports tool_call?  #{Examples.LoggingBackend.supports?(tool_job)}")
IO.puts("  Local supports tool_call?           #{NsaiWork.Backends.Local.supports?(tool_job)}")

GenServer.stop(executor)

IO.puts("\n=== Done ===")
