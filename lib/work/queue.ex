defmodule Work.Queue do
  @moduledoc """
  Priority queue implementation for job scheduling.

  Queues are organized by priority level:
  - `:realtime` - Highest priority, immediate execution
  - `:interactive` - High priority, user-facing
  - `:batch` - Normal priority, background work
  - `:offline` - Lowest priority, bulk processing

  Each queue maintains FIFO ordering within its priority level.
  """

  use GenServer
  require Logger

  alias Work.{Job, Telemetry}

  @type priority :: :realtime | :interactive | :batch | :offline
  @type t :: %__MODULE__{
          name: atom(),
          priority: priority(),
          jobs: :queue.queue(),
          max_size: non_neg_integer() | :unlimited
        }

  defstruct [:name, :priority, jobs: :queue.new(), max_size: :unlimited]

  ## Client API

  @doc """
  Starts a queue.

  ## Options

    * `:name` - Queue name (required)
    * `:priority` - Queue priority (default: :batch)
    * `:max_size` - Maximum queue size (default: :unlimited)
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Enqueues a job.

  Returns `{:ok, job}` if successful, `{:error, :queue_full}` if at capacity.

  ## Examples

      iex> Work.Queue.enqueue(queue_pid, job)
      {:ok, job}
  """
  @spec enqueue(GenServer.server(), Job.t()) :: {:ok, Job.t()} | {:error, :queue_full}
  def enqueue(queue, %Job{} = job) do
    GenServer.call(queue, {:enqueue, job})
  end

  @doc """
  Dequeues the next job.

  Returns `{:ok, job}` if a job is available, `{:error, :empty}` if queue is empty.

  ## Examples

      iex> Work.Queue.dequeue(queue_pid)
      {:ok, %Work.Job{}}
  """
  @spec dequeue(GenServer.server()) :: {:ok, Job.t()} | {:error, :empty}
  def dequeue(queue) do
    GenServer.call(queue, :dequeue)
  end

  @doc """
  Returns the current queue size.

  ## Examples

      iex> Work.Queue.size(queue_pid)
      42
  """
  @spec size(GenServer.server()) :: non_neg_integer()
  def size(queue) do
    GenServer.call(queue, :size)
  end

  @doc """
  Returns queue statistics.

  ## Examples

      iex> Work.Queue.stats(queue_pid)
      %{
        name: :batch_queue,
        priority: :batch,
        size: 42,
        max_size: :unlimited
      }
  """
  @spec stats(GenServer.server()) :: map()
  def stats(queue) do
    GenServer.call(queue, :stats)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      priority: Keyword.get(opts, :priority, :batch),
      max_size: Keyword.get(opts, :max_size, :unlimited),
      jobs: :queue.new()
    }

    Logger.info("Work.Queue #{state.name} started (priority: #{state.priority})")

    {:ok, state}
  end

  @impl true
  def handle_call({:enqueue, job}, _from, state) do
    current_size = :queue.len(state.jobs)

    cond do
      state.max_size != :unlimited and current_size >= state.max_size ->
        Telemetry.queue_overflow(state.name)
        {:reply, {:error, :queue_full}, state}

      true ->
        updated_jobs = :queue.in(job, state.jobs)
        Telemetry.queue_enqueue(state.name, job)
        {:reply, {:ok, job}, %{state | jobs: updated_jobs}}
    end
  end

  @impl true
  def handle_call(:dequeue, _from, state) do
    case :queue.out(state.jobs) do
      {{:value, job}, updated_jobs} ->
        Telemetry.queue_dequeue(state.name, job)
        {:reply, {:ok, job}, %{state | jobs: updated_jobs}}

      {:empty, _} ->
        {:reply, {:error, :empty}, state}
    end
  end

  @impl true
  def handle_call(:size, _from, state) do
    {:reply, :queue.len(state.jobs), state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      name: state.name,
      priority: state.priority,
      size: :queue.len(state.jobs),
      max_size: state.max_size
    }

    {:reply, stats, state}
  end
end
