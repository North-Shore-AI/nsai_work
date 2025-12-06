defmodule Work.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the job registry
      Work.Registry,

      # Start the executor
      Work.Executor,

      # Start the scheduler (which starts queues)
      Work.Scheduler
    ]

    opts = [strategy: :one_for_one, name: Work.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
