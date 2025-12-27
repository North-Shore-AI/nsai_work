defmodule Work.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # ALTAR registry (if enabled)
        altar_child_spec(),

        # Start the job registry
        Work.Registry,

        # Start the executor
        Work.Executor,

        # Start the scheduler (which starts queues)
        Work.Scheduler
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: Work.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Private helpers

  defp altar_child_spec do
    if Application.get_env(:work, :enable_altar, false) do
      registry_name = Application.get_env(:work, :altar_registry, Work.AltarRegistry)

      {Altar.Supervisor, name: registry_name}
    end
  end
end
