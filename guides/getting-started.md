# Getting Started

This guide walks through the basics of NsaiWork: creating jobs, submitting them for execution, and checking results.

## Starting the Application

NsaiWork starts automatically as an OTP application. In your project:

```elixir
{:ok, _} = Application.ensure_all_started(:nsai_work)
```

This boots the supervision tree: Registry, Executor, and Scheduler.

## Creating a Job

Every job requires a `kind`, `tenant_id`, and `namespace`:

```elixir
job = NsaiWork.Job.new(
  kind: :tool_call,
  tenant_id: "acme",
  namespace: "default",
  payload: %{tool: "echo", args: ["hello"]}
)
```

Jobs are created with status `:pending` and auto-generated `id` and `trace_id` fields.

### Job Kinds

NsaiWork supports several job kinds:

| Kind | Use Case |
|------|----------|
| `:tool_call` | ALTAR/GRID tool invocations |
| `:experiment_step` | Crucible ML experiment stages |
| `:workflow_step` | Synapse DAG steps |
| `:training_step` | Model training |
| `:inference` | Inference requests |
| `:backend_command` | Administrative commands |
| `:composite` | Multi-step jobs |

### Priority Levels

Set priority to control queue routing:

```elixir
job = NsaiWork.Job.new(
  kind: :tool_call,
  tenant_id: "acme",
  namespace: "default",
  priority: :realtime,  # :realtime | :interactive | :batch | :offline
  payload: %{tool: "echo", args: ["urgent"]}
)
```

The default priority is `:batch`.

## Submitting a Job

```elixir
{:ok, submitted} = NsaiWork.submit(job)
IO.puts("Job #{submitted.id} is #{submitted.status}")
```

On success, the job transitions through `pending -> queued -> running -> succeeded`.

## Checking Job Status

Retrieve a job by ID:

```elixir
{:ok, job} = NsaiWork.get(submitted.id)
IO.inspect(job.status)   # :succeeded, :failed, :running, etc.
IO.inspect(job.result)   # the result payload on success
```

## Listing Jobs

List all jobs for a tenant:

```elixir
jobs = NsaiWork.list("acme")
```

With filters:

```elixir
# By namespace
jobs = NsaiWork.list("acme", namespace: "default")

# By status
running = NsaiWork.list("acme", status: :running)

# With limit
recent = NsaiWork.list("acme", limit: 10)
```

## Statistics

Get scheduler and registry stats:

```elixir
stats = NsaiWork.stats()

# Scheduler stats: queue sizes, executing count, max_concurrent
IO.inspect(stats.scheduler)

# Registry stats: total jobs, breakdown by status and tenant
IO.inspect(stats.registry)
```

## Resource Requirements

Specify what a job needs to run:

```elixir
job = NsaiWork.Job.new(
  kind: :training_step,
  tenant_id: "acme",
  namespace: "ml",
  payload: %{model: "llama-3.1-8b"},
  resources: NsaiWork.Resources.new(
    cpu: 4.0,
    memory_mb: 8192,
    gpu: "A100",
    gpu_count: 1,
    timeout_ms: 300_000,
    max_cost_usd: 1.0
  )
)
```

Resource-aware scheduling uses these fields to select appropriate backends. Jobs requiring GPUs will not be routed to the Local backend.

## Next Steps

- [Custom Backends](custom-backends.md) — implement your own execution backend
- [Telemetry](telemetry.md) — observe job lifecycle events
- [Examples](../examples/README.md) — runnable scripts
