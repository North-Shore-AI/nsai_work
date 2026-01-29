# Custom Backends

NsaiWork uses pluggable backends to execute jobs. This guide covers the backend behaviour, built-in backends, and how to write your own.

## The Backend Behaviour

All backends implement `NsaiWork.Backend`:

```elixir
@callback execute(Job.t()) :: {:ok, term()} | {:error, Error.t()}
@callback cancel(job_id :: String.t()) :: :ok | {:error, Error.t()}
@callback status(job_id :: String.t()) :: {:ok, map()} | {:error, Error.t()}
@callback supports?(Job.t()) :: boolean()
```

Only `execute/1` and `supports?/1` are required. Default implementations of `cancel/1` and `status/1` return `{:error, :not_supported}`.

## Built-In Backends

### Local

`NsaiWork.Backends.Local` runs jobs directly in the BEAM. It supports `:tool_call` and `:backend_command` kinds, and rejects jobs that require GPUs.

### ALTAR

`NsaiWork.Backends.Altar` delegates `:tool_call` jobs to ALTAR's LATER runtime. Enable it in config:

```elixir
config :nsai_work,
  enable_altar: true,
  altar_registry: NsaiWork.AltarRegistry
```

Then register tools via `NsaiWork.AltarTools.register/4` before submitting jobs.

## Writing a Custom Backend

Here's a complete example — a backend that logs execution and delegates to a remote HTTP service:

```elixir
defmodule MyApp.Backends.Remote do
  @behaviour NsaiWork.Backend

  require Logger

  @impl true
  def execute(%NsaiWork.Job{} = job) do
    Logger.info("Executing job #{job.id} (#{job.kind}) on remote backend")

    case post_to_remote(job) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, NsaiWork.Error.new(
          category: :backend,
          code: "REMOTE_ERROR",
          message: "Remote returned status #{status}",
          retryable: status >= 500
        )}

      {:error, reason} ->
        {:error, NsaiWork.Error.new(
          category: :network,
          code: "CONNECTION_FAILED",
          message: "Failed to reach remote: #{inspect(reason)}",
          retryable: true
        )}
    end
  end

  @impl true
  def supports?(%NsaiWork.Job{kind: kind}) do
    kind in [:tool_call, :inference]
  end

  defp post_to_remote(job) do
    # Your HTTP client logic here
    {:ok, %{status: 200, body: %{result: "ok"}}}
  end
end
```

### Key Points

- **`supports?/1`** controls routing. The Executor calls `supports?/1` on each backend to decide where a job runs. Return `true` only for job kinds your backend can handle.
- **`execute/1`** receives the full `Job` struct. Use `job.payload`, `job.resources`, and `job.constraints` to determine how to run it.
- **Error reporting** — return `NsaiWork.Error` structs with `retryable: true` for transient failures. The Executor will retry according to the job's constraints.

## Registering a Custom Backend

Pass your backend to the Executor at startup:

```elixir
# In your application supervision tree
children = [
  {NsaiWork.Executor, backends: %{
    local: NsaiWork.Backends.Local,
    remote: MyApp.Backends.Remote
  }}
]
```

Or configure it in your application config and let NsaiWork's supervision tree handle it.

## Backend Selection

The Executor selects a backend by:

1. Checking `job.constraints.required_backends` — if set, only those backends are considered
2. Checking `job.constraints.excluded_backends` — skip these
3. Calling `supports?/1` on remaining backends
4. Preferring backends listed in `job.constraints.preferred_backends`

This lets jobs express backend preferences without hard-coding execution targets.
