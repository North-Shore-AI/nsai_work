defmodule Work.Scheduler do
  @moduledoc """
  Job scheduler with priority queue management.

  The Scheduler:
  1. Receives job submissions
  2. Admits jobs based on quotas and policies
  3. Routes jobs to appropriate priority queues
  4. Dispatches jobs to executor when workers available
  """

  use GenServer
  require Logger

  alias Work.{Job, Queue, Registry, Executor, Telemetry}

  @priorities [:realtime, :interactive, :batch, :offline]

  ## Client API

  @doc """
  Starts the scheduler.

  ## Options

    * `:max_concurrent` - Maximum concurrent jobs (default: 10)
    * `:queue_opts` - Options for each queue
    * `:name` - GenServer name
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Submits a job for scheduling.

  ## Examples

      iex> Work.Scheduler.submit(job)
      {:ok, job}
  """
  @spec submit(Job.t()) :: {:ok, Job.t()} | {:error, term()}
  def submit(%Job{} = job) do
    GenServer.call(__MODULE__, {:submit, job})
  end

  @doc """
  Returns scheduler statistics.

  ## Examples

      iex> Work.Scheduler.stats()
      %{
        queues: %{
          realtime: %{size: 0},
          interactive: %{size: 5},
          batch: %{size: 42}
        },
        executing: 3,
        max_concurrent: 10
      }
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    max_concurrent = Keyword.get(opts, :max_concurrent, 10)
    queue_opts = Keyword.get(opts, :queue_opts, [])

    # Start priority queues
    queues =
      @priorities
      |> Enum.map(fn priority ->
        opts =
          [
            name: queue_name(priority),
            priority: priority
          ] ++ queue_opts

        {:ok, pid} = Queue.start_link(opts)
        {priority, pid}
      end)
      |> Map.new()

    state = %{
      queues: queues,
      max_concurrent: max_concurrent,
      executing: 0
    }

    Logger.info("Work.Scheduler started (max_concurrent: #{max_concurrent})")

    # Start dispatch loop
    schedule_dispatch()

    {:ok, state}
  end

  @impl true
  def handle_call({:submit, job}, _from, state) do
    # Admit job
    {:accept, queue_priority} = admit(job, state)

    # Mark as queued
    job = Job.mark_queued(job)
    Registry.put(job)
    Telemetry.job_submitted(job)

    # Enqueue
    queue_pid = state.queues[queue_priority]

    case Queue.enqueue(queue_pid, job) do
      {:ok, job} ->
        Telemetry.job_queued(job, queue_priority)
        {:reply, {:ok, job}, state}

      {:error, :queue_full} ->
        {:reply, {:error, :queue_full}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    queue_stats =
      state.queues
      |> Enum.map(fn {priority, pid} ->
        {priority, Queue.stats(pid)}
      end)
      |> Map.new()

    stats = %{
      queues: queue_stats,
      executing: state.executing,
      max_concurrent: state.max_concurrent
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:dispatch, state) do
    # Dispatch jobs if capacity available
    state =
      if state.executing < state.max_concurrent do
        dispatch_next(state)
      else
        state
      end

    # Schedule next dispatch
    schedule_dispatch()

    {:noreply, state}
  end

  @impl true
  def handle_info({:job_completed, _job_id}, state) do
    # Decrement executing count
    state = %{state | executing: max(0, state.executing - 1)}
    {:noreply, state}
  end

  ## Private Functions

  defp admit(job, _state) do
    # Simple admission - accept all jobs to their priority queue
    # In production, check quotas, tenant limits, etc.
    queue_priority = job.priority
    decision = {:accept, queue_priority}
    Telemetry.scheduler_admit(job, decision)
    decision
  end

  defp dispatch_next(state) do
    # Try to dequeue from highest priority queue with jobs
    case find_next_job(state.queues) do
      {:ok, job} ->
        # Execute job
        Executor.execute(job)

        # Increment executing count
        %{state | executing: state.executing + 1}

      :empty ->
        state
    end
  end

  defp find_next_job(queues) do
    # Try queues in priority order
    @priorities
    |> Enum.find_value(fn priority ->
      queue_pid = queues[priority]

      case Queue.dequeue(queue_pid) do
        {:ok, job} -> {:found, job}
        {:error, :empty} -> nil
      end
    end)
    |> case do
      {:found, job} -> {:ok, job}
      nil -> :empty
    end
  end

  defp schedule_dispatch do
    # Dispatch every 100ms
    Process.send_after(self(), :dispatch, 100)
  end

  defp queue_name(priority) do
    :"work_queue_#{priority}"
  end
end
