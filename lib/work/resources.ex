defmodule Work.Resources do
  @moduledoc """
  Resource requirements for job scheduling.

  Defines compute, time, cost, storage, and network requirements
  that guide job placement and backend selection.
  """

  @type t :: %__MODULE__{
          cpu: float() | nil,
          memory_mb: non_neg_integer() | nil,
          gpu: String.t() | nil,
          gpu_count: non_neg_integer(),
          timeout_ms: non_neg_integer() | nil,
          estimated_duration_ms: non_neg_integer() | nil,
          max_cost_usd: float() | nil,
          storage_mb: non_neg_integer() | nil,
          requires_network: boolean(),
          requires_external_api: boolean()
        }

  defstruct cpu: nil,
            memory_mb: nil,
            gpu: nil,
            gpu_count: 0,
            timeout_ms: nil,
            estimated_duration_ms: nil,
            max_cost_usd: nil,
            storage_mb: nil,
            requires_network: true,
            requires_external_api: true

  @doc """
  Creates a new Resources struct with the given attributes.

  ## Examples

      iex> Work.Resources.new(cpu: 2.0, memory_mb: 4096, gpu: "A100")
      %Work.Resources{cpu: 2.0, memory_mb: 4096, gpu: "A100"}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  Returns true if the job requires GPU resources.

  ## Examples

      iex> Work.Resources.new(gpu: "A100") |> Work.Resources.requires_gpu?()
      true

      iex> Work.Resources.new() |> Work.Resources.requires_gpu?()
      false
  """
  @spec requires_gpu?(t()) :: boolean()
  def requires_gpu?(%__MODULE__{gpu: gpu}) when is_binary(gpu), do: true
  def requires_gpu?(%__MODULE__{gpu_count: count}) when count > 0, do: true
  def requires_gpu?(_), do: false
end
