defmodule NsaiWork.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # ALTAR registry (if enabled)
        altar_child_spec(),

        # Start the job registry
        NsaiWork.Registry,

        # Start the executor
        NsaiWork.Executor,

        # Start the scheduler (which starts queues)
        NsaiWork.Scheduler
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: NsaiWork.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Private helpers

  defp altar_child_spec do
    if Application.get_env(:nsai_work, :enable_altar, false) do
      registry_name = Application.get_env(:nsai_work, :altar_registry, NsaiWork.AltarRegistry)

      {Altar.Supervisor, name: registry_name}
    end
  end
end
