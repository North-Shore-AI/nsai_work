defmodule Work.Constraints do
  @moduledoc """
  Scheduling constraints for job placement.

  Defines retry policies, backend requirements, affinity,
  dependencies, timing, and concurrency constraints.
  """

  @type retry_policy :: %{
          max_attempts: non_neg_integer(),
          backoff: :exponential | :linear | :constant,
          base_delay_ms: non_neg_integer(),
          max_delay_ms: non_neg_integer(),
          jitter: boolean()
        }

  @type locality :: :any | :local | :region

  @type t :: %__MODULE__{
          retry_policy: retry_policy(),
          required_backends: [atom()],
          preferred_backends: [atom()],
          excluded_backends: [atom()],
          session_id: String.t() | nil,
          locality: locality(),
          depends_on: [String.t()],
          blocks: [String.t()],
          not_before: DateTime.t() | nil,
          deadline: DateTime.t() | nil,
          concurrency_group: String.t() | nil,
          max_concurrent_in_group: non_neg_integer() | nil
        }

  defstruct retry_policy: %{
              max_attempts: 3,
              backoff: :exponential,
              base_delay_ms: 1000,
              max_delay_ms: 60_000,
              jitter: true
            },
            required_backends: [],
            preferred_backends: [],
            excluded_backends: [],
            session_id: nil,
            locality: :any,
            depends_on: [],
            blocks: [],
            not_before: nil,
            deadline: nil,
            concurrency_group: nil,
            max_concurrent_in_group: nil

  @doc """
  Creates a new Constraints struct with the given attributes.

  ## Examples

      iex> Work.Constraints.new(
      ...>   required_backends: [:local],
      ...>   concurrency_group: "model_training"
      ...> )
      %Work.Constraints{
        required_backends: [:local],
        concurrency_group: "model_training"
      }
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    # Merge retry_policy if provided
    opts =
      if retry_policy = opts[:retry_policy] do
        default_retry = %__MODULE__{}.retry_policy
        merged_retry = Map.merge(default_retry, Map.new(retry_policy))
        Keyword.put(opts, :retry_policy, merged_retry)
      else
        opts
      end

    struct(__MODULE__, opts)
  end

  @doc """
  Calculates the delay for the next retry attempt.

  ## Examples

      iex> constraints = Work.Constraints.new()
      iex> Work.Constraints.retry_delay(constraints, 0)
      1000

      iex> constraints = Work.Constraints.new()
      iex> delay = Work.Constraints.retry_delay(constraints, 1)
      iex> delay >= 2000 and delay <= 2100
      true
  """
  @spec retry_delay(t(), non_neg_integer()) :: non_neg_integer()
  def retry_delay(%__MODULE__{retry_policy: policy}, attempt) do
    base_delay = policy.base_delay_ms

    delay =
      case policy.backoff do
        :constant ->
          base_delay

        :linear ->
          base_delay * (attempt + 1)

        :exponential ->
          min(base_delay * :math.pow(2, attempt), policy.max_delay_ms)
      end

    if policy.jitter do
      # Add up to 5% jitter
      jitter = :rand.uniform() * delay * 0.05
      trunc(delay + jitter)
    else
      trunc(delay)
    end
  end

  @doc """
  Returns true if the job can be retried based on attempt count.

  ## Examples

      iex> constraints = Work.Constraints.new()
      iex> Work.Constraints.can_retry?(constraints, 0)
      true

      iex> constraints = Work.Constraints.new()
      iex> Work.Constraints.can_retry?(constraints, 3)
      false
  """
  @spec can_retry?(t(), non_neg_integer()) :: boolean()
  def can_retry?(%__MODULE__{retry_policy: policy}, attempt) do
    attempt < policy.max_attempts
  end
end
