defmodule Work.Error do
  @moduledoc """
  Standardized error representation for jobs.

  Errors are categorized by type to enable intelligent retry logic
  and failure handling.
  """

  @type category ::
          :validation
          | :resource
          | :timeout
          | :backend
          | :network
          | :quota
          | :permission
          | :internal
          | :canceled

  @type t :: %__MODULE__{
          category: category(),
          code: String.t(),
          message: String.t(),
          details: map(),
          retryable: boolean(),
          retry_after_ms: non_neg_integer() | nil,
          stacktrace: String.t() | nil
        }

  defstruct [
    :category,
    :code,
    :message,
    details: %{},
    retryable: false,
    retry_after_ms: nil,
    stacktrace: nil
  ]

  @doc """
  Creates a new error with the given attributes.

  ## Examples

      iex> Work.Error.new(
      ...>   category: :timeout,
      ...>   code: "JOB_TIMEOUT",
      ...>   message: "Job exceeded time limit",
      ...>   retryable: true
      ...> )
      %Work.Error{
        category: :timeout,
        code: "JOB_TIMEOUT",
        message: "Job exceeded time limit",
        retryable: true
      }
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    struct(__MODULE__, opts)
  end

  @doc """
  Creates an error from an exception.

  ## Examples

      iex> error = Work.Error.from_exception(%RuntimeError{message: "oops"})
      iex> error.category
      :internal
  """
  @spec from_exception(Exception.t()) :: t()
  def from_exception(exception) do
    new(
      category: :internal,
      code: exception.__struct__ |> to_string() |> String.split(".") |> List.last(),
      message: Exception.message(exception),
      stacktrace:
        Exception.format_stacktrace(Process.info(self(), :current_stacktrace) |> elem(1))
    )
  end
end
