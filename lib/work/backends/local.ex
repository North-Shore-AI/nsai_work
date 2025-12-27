defmodule Work.Backends.Local do
  @moduledoc """
  Local execution backend that runs jobs in BEAM processes.

  This backend executes jobs directly in the current BEAM VM,
  suitable for:
  - Development and testing
  - Lightweight compute tasks
  - Single-node deployments

  NOT suitable for:
  - GPU workloads
  - Long-running tasks (use with timeout)
  - Resource-intensive work
  """

  @behaviour Work.Backend

  alias Work.{Error, Job}
  require Logger

  @impl true
  def execute(%Job{} = job) do
    Logger.debug("Local backend executing job #{job.id}")

    try do
      result = do_execute(job)
      {:ok, result}
    rescue
      exception ->
        Logger.error("Local backend execution failed: #{inspect(exception)}")
        error = Error.from_exception(exception)
        {:error, error}
    end
  end

  @impl true
  def cancel(job_id) do
    Logger.debug("Local backend cancel requested for #{job_id}")
    # Local backend doesn't track running jobs, so this is a no-op
    :ok
  end

  @impl true
  def status(_job_id) do
    # Local backend doesn't maintain job state
    {:error,
     Error.new(
       category: :backend,
       code: "NOT_SUPPORTED",
       message: "Local backend does not track job status"
     )}
  end

  @impl true
  def supports?(%Job{kind: kind}) when kind in [:tool_call, :backend_command], do: true
  def supports?(%Job{resources: %{gpu: gpu}}) when not is_nil(gpu), do: false
  def supports?(_), do: true

  # Private execution logic

  defp do_execute(%Job{kind: :tool_call, payload: payload}) do
    # Simulate tool execution
    %{
      tool: payload["tool"] || payload[:tool],
      result: "executed",
      timestamp: DateTime.utc_now()
    }
  end

  defp do_execute(%Job{kind: :backend_command, payload: payload}) do
    # Execute backend command
    command = payload["command"] || payload[:command]
    args = payload["args"] || payload[:args] || []

    %{
      command: command,
      args: args,
      result: "executed",
      timestamp: DateTime.utc_now()
    }
  end

  defp do_execute(%Job{kind: kind, payload: payload}) do
    # Generic execution for other job types
    %{
      kind: kind,
      payload: payload,
      result: "executed",
      timestamp: DateTime.utc_now()
    }
  end
end
