defmodule NsaiWork.Backends.Altar do
  @moduledoc """
  ALTAR backend for Work job execution.

  Delegates tool_call jobs to ALTAR's LATER runtime,
  converting between NsaiWork.Job and ADM structures.

  ALTAR (Adaptive Language Tool and Action Runtime) provides:
  - ADM (data model) for function declarations and calls
  - LATER (local execution runtime) for tool execution

  ## Configuration

  Configure the ALTAR registry name in your application config:

      config :nsai_work,
        enable_altar: true,
        altar_registry: NsaiWork.AltarRegistry

  ## Supported Job Types

  Currently supports:
  - `:tool_call` - Tool invocations via ALTAR's LATER runtime

  ## Job Payload Format

  For `:tool_call` jobs, the payload should contain:

      %{
        "tool_name" => "function_name",  # or :tool_name
        "args" => %{...}                  # or :args
      }

  ## Examples

      # Create a tool call job
      job = NsaiWork.Job.new(
        kind: :tool_call,
        tenant_id: "acme",
        namespace: "default",
        payload: %{
          tool_name: "proposer_extract",
          args: %{doc_id: "doc_123"}
        }
      )

      # Execute via ALTAR backend
      {:ok, result} = NsaiWork.Backends.Altar.execute(job)
  """

  @behaviour NsaiWork.Backend

  alias Altar.ADM.{FunctionCall, ToolResult}
  alias Altar.LATER.Executor
  alias NsaiWork.{Error, Job}
  require Logger

  @impl true
  def execute(%Job{kind: :tool_call} = job) do
    Logger.debug("ALTAR backend executing job #{job.id}")

    # Convert NsaiWork.Job to FunctionCall
    call = job_to_function_call(job)

    # Execute via ALTAR (always returns {:ok, ToolResult.t()})
    {:ok, result} = Executor.execute_tool(registry_name(), call)

    case result do
      %ToolResult{is_error: false} ->
        Logger.debug("ALTAR execution succeeded for job #{job.id}")
        {:ok, result.content}

      %ToolResult{is_error: true} ->
        Logger.warning("ALTAR execution failed for job #{job.id}: #{inspect(result.content)}")

        {:error,
         Error.new(
           category: :backend,
           code: "ALTAR_TOOL_ERROR",
           message: "Tool execution failed",
           details: result.content,
           retryable: true
         )}
    end
  end

  def execute(%Job{} = job) do
    {:error,
     Error.new(
       category: :backend,
       code: "UNSUPPORTED_JOB_KIND",
       message: "ALTAR backend only supports :tool_call jobs, got: #{job.kind}",
       retryable: false
     )}
  end

  @impl true
  def cancel(_job_id) do
    {:error,
     Error.new(
       category: :backend,
       code: "NOT_IMPLEMENTED",
       message: "ALTAR backend does not support job cancellation",
       retryable: false
     )}
  end

  @impl true
  def status(_job_id) do
    {:error,
     Error.new(
       category: :backend,
       code: "NOT_IMPLEMENTED",
       message: "ALTAR backend does not track job status",
       retryable: false
     )}
  end

  @impl true
  def supports?(%Job{kind: :tool_call}), do: true
  def supports?(%Job{}), do: false

  # Private helpers

  defp job_to_function_call(%Job{id: id, payload: payload}) do
    tool_name = payload["tool_name"] || payload[:tool_name]
    args = payload["args"] || payload[:args] || %{}

    %FunctionCall{
      call_id: id,
      name: tool_name,
      args: args
    }
  end

  defp registry_name do
    Application.get_env(:nsai_work, :altar_registry, NsaiWork.AltarRegistry)
  end
end
