defmodule Work.Backend do
  @moduledoc """
  Behaviour for job execution backends.

  Backends are pluggable executors that can run jobs on different
  infrastructure:
  - Local: Direct BEAM process execution
  - ALTAR: Distributed tool execution
  - Modal: Serverless GPU compute
  - Ray: Distributed Python computing

  ## Implementation

  Backends must implement:
  - `execute/1` - Execute a job and return result
  - `cancel/1` - Cancel a running job
  - `status/1` - Get status of a job
  - `supports?/1` - Check if job type is supported
  """

  alias Work.{Job, Error}

  @type execute_result :: {:ok, term()} | {:error, Error.t()}
  @type cancel_result :: :ok | {:error, Error.t()}
  @type status_result :: {:ok, map()} | {:error, Error.t()}

  @doc """
  Execute a job and return its result.

  The backend should:
  1. Validate the job payload
  2. Execute the work
  3. Return the result or error

  ## Examples

      defmodule MyBackend do
        @behaviour Work.Backend

        @impl true
        def execute(job) do
          # Execute work
          {:ok, result}
        end
      end
  """
  @callback execute(Job.t()) :: execute_result()

  @doc """
  Cancel a running job.

  Should gracefully stop execution if possible.
  """
  @callback cancel(job_id :: String.t()) :: cancel_result()

  @doc """
  Get the current status of a job.

  Returns a map with backend-specific status information.
  """
  @callback status(job_id :: String.t()) :: status_result()

  @doc """
  Check if this backend supports the given job type.

  ## Examples

      @impl true
      def supports?(%Job{kind: :tool_call}), do: true
      def supports?(_), do: false
  """
  @callback supports?(Job.t()) :: boolean()

  @optional_callbacks cancel: 1, status: 1
end
