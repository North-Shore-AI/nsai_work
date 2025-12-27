# NSAI.Work

**Unified job scheduler for the North-Shore-AI platform**

[![Hex.pm](https://img.shields.io/hexpm/v/work.svg)](https://hex.pm/packages/work)
[![Documentation](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/work)

NSAI.Work provides a protocol-first, multi-tenant job scheduling system with priority queues, resource-aware scheduling, and pluggable backend execution.

## Features

- **Unified Job IR**: Single representation for all work types (tool calls, experiments, training, inference)
- **Priority Queues**: Four levels (realtime/interactive/batch/offline) with FIFO ordering
- **Multi-Tenancy**: Tenant isolation with quotas and fairness
- **Resource-Aware**: CPU, GPU, memory, cost-aware scheduling
- **Pluggable Backends**: Local, ALTAR, Modal, Ray, and custom backends
- **Retry Policies**: Configurable exponential/linear/constant backoff
- **Telemetry Integration**: Full observability via Erlang telemetry
- **ETS-Based Registry**: Fast in-memory job storage and indexing

## Installation

Add `work` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:work, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Start the application
{:ok, _} = Application.ensure_all_started(:work)

# Create a job
job = Work.Job.new(
  kind: :tool_call,
  tenant_id: "acme",
  namespace: "default",
  priority: :interactive,
  payload: %{tool: "calculator", args: [2, 2]},
  resources: Work.Resources.new(cpu: 1.0, memory_mb: 512)
)

# Submit for execution
{:ok, submitted} = Work.submit(job)

# Check status
{:ok, job} = Work.get(submitted.id)
IO.inspect(job.status)  # => :running or :succeeded

# Get statistics
stats = Work.stats()
IO.inspect(stats)
```

## Architecture

NSAI.Work consists of several cooperating components:

```
┌─────────────────────────────────────────────────┐
│              Application Layer                  │
│  (Crucible, Synapse, CNS, ALTAR, etc.)          │
└────────────────────┬────────────────────────────┘
                     │ submit jobs
                     ▼
┌─────────────────────────────────────────────────┐
│              Work.Scheduler                     │
│  - Admission control                            │
│  - Priority queue routing                       │
│  - Resource-aware dispatch                      │
└────────────────────┬────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
   [realtime]  [interactive]  [batch]  [offline]
        │            │            │         │
        └────────────┴────────────┴─────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│              Work.Executor                      │
│  - Backend selection                            │
│  - Job execution                                │
│  - Retry handling                               │
└────────────────────┬────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
    [Local]      [ALTAR]      [Modal]  [Custom]
```

### Components

- **Work.Job**: Universal job IR with metadata, resources, constraints
- **Work.Scheduler**: Priority queue management and admission control
- **Work.Queue**: FIFO queues per priority level
- **Work.Executor**: Job execution with backend delegation
- **Work.Registry**: ETS-based job storage and indexing
- **Work.Backend**: Pluggable execution backends
- **Work.Telemetry**: Event instrumentation

## Job Lifecycle

Jobs move through the following states:

```
pending -> queued -> running -> {succeeded | failed | canceled | timeout}
                                       ↓
                                  (retry) -> queued
```

1. **pending**: Job created, waiting for admission
2. **queued**: Admitted and waiting in priority queue
3. **running**: Executing on a backend
4. **succeeded**: Completed successfully
5. **failed**: Execution failed (may retry)
6. **canceled**: Explicitly canceled
7. **timeout**: Exceeded time limit

## Priority Levels

Jobs are scheduled based on four priority levels:

- **realtime**: Immediate execution, user-blocking operations
- **interactive**: User-facing operations with quick turnaround
- **batch**: Background processing, experiments, training
- **offline**: Bulk operations, data processing, low priority

## Resource Requirements

Specify resource requirements for intelligent scheduling:

```elixir
resources = Work.Resources.new(
  cpu: 4.0,                    # CPU cores
  memory_mb: 8192,             # Memory in MB
  gpu: "A100",                 # GPU type
  gpu_count: 1,                # Number of GPUs
  timeout_ms: 300_000,         # 5 minute timeout
  max_cost_usd: 1.0            # Cost cap
)

job = Work.Job.new(
  kind: :training_step,
  tenant_id: "acme",
  namespace: "ml",
  payload: %{model: "llama-3.1-8b"},
  resources: resources
)
```

## Retry Policies

Configure retry behavior per job:

```elixir
constraints = Work.Constraints.new(
  retry_policy: %{
    max_attempts: 5,
    backoff: :exponential,
    base_delay_ms: 1000,
    max_delay_ms: 60_000,
    jitter: true
  }
)

job = Work.Job.new(
  kind: :tool_call,
  tenant_id: "acme",
  namespace: "default",
  payload: %{},
  constraints: constraints
)
```

## Backends

NSAI.Work ships with three built-in backends:

### Local Backend

Direct BEAM process execution (development, lightweight tasks):

```elixir
# Automatically selected for simple jobs
job = Work.Job.new(
  kind: :tool_call,
  tenant_id: "test",
  namespace: "default",
  payload: %{tool: "echo"}
)
```

### ALTAR Backend

Executes tool calls via ALTAR's LATER runtime with ADM function declarations:

```elixir
# Enable ALTAR in config
config :work,
  enable_altar: true,
  altar_registry: Work.AltarRegistry

# Register a tool
Work.AltarTools.register(
  "proposer_extract",
  "Extract claims from document",
  %{
    type: :OBJECT,
    properties: %{
      "doc_id" => %{type: :STRING, description: "Document ID"},
      "max_claims" => %{type: :NUMBER, description: "Max claims"}
    },
    required: ["doc_id"]
  },
  &MyApp.CNS.Proposer.extract/1
)

# Submit a tool call job
job = Work.Job.new(
  kind: :tool_call,
  tenant_id: "acme",
  namespace: "cns",
  payload: %{
    tool_name: "proposer_extract",
    args: %{doc_id: "doc_123", max_claims: 10}
  }
)

{:ok, job} = Work.submit(job)
```

See the [ALTAR Integration](#altar-integration) section for more details.

### Mock Backend

Testing backend with configurable behavior:

```elixir
# Configure mock to fail
Work.Backends.Mock.configure(behavior: {:fail, "Simulated failure"})

# Or delay execution
Work.Backends.Mock.configure(delay_ms: 500)

# Check execution history
history = Work.Backends.Mock.history()
```

### Custom Backends

Implement the `Work.Backend` behaviour:

```elixir
defmodule MyApp.Backend.Custom do
  @behaviour Work.Backend

  @impl true
  def execute(job) do
    # Your execution logic
    {:ok, result}
  end

  @impl true
  def supports?(job) do
    job.kind == :custom_work
  end
end

# Configure executor with custom backend
Work.Executor.start_link(
  backends: [
    local: Work.Backends.Local,
    custom: MyApp.Backend.Custom
  ]
)
```

## Telemetry

NSAI.Work emits telemetry events for observability:

```elixir
# Attach a handler
:telemetry.attach(
  "work-metrics",
  [:work, :job, :completed],
  &MyApp.Metrics.handle_event/4,
  nil
)

# Or use the built-in console logger
Work.Telemetry.attach_console_logger()
```

### Events

- `[:work, :job, :submitted]` - Job submitted
- `[:work, :job, :queued]` - Job enqueued
- `[:work, :job, :started]` - Job execution started
- `[:work, :job, :completed]` - Job completed
- `[:work, :job, :canceled]` - Job canceled
- `[:work, :job, :retry]` - Job retry scheduled
- `[:work, :scheduler, :admit]` - Admission decision
- `[:work, :scheduler, :select_backend]` - Backend selection
- `[:work, :queue, :enqueue]` - Queue enqueue
- `[:work, :queue, :dequeue]` - Queue dequeue
- `[:work, :queue, :overflow]` - Queue capacity exceeded

## Multi-Tenancy

All jobs belong to a tenant and namespace:

```elixir
job = Work.Job.new(
  tenant_id: "customer-123",
  namespace: "production",
  # ...
)

# List jobs for a tenant
jobs = Work.list("customer-123")

# Filter by namespace
jobs = Work.list("customer-123", namespace: "production")

# Filter by status
running = Work.list("customer-123", status: :running)
```

## ALTAR Integration

ALTAR (Adaptive Language Tool and Action Runtime) provides a local execution runtime for tool calls with ADM (function declaration) support. The ALTAR backend enables Work to execute tool calls through ALTAR's LATER runtime.

### Setup

1. Add ALTAR to your dependencies (already included with Work):

```elixir
{:altar, "~> 0.2.0"}
```

2. Enable ALTAR in your application config:

```elixir
# config/config.exs
config :work,
  enable_altar: true,
  altar_registry: Work.AltarRegistry
```

### Registering Tools

Use `Work.AltarTools` to register tools with ALTAR:

```elixir
# Simple tool
Work.AltarTools.register(
  "calculator_add",
  "Add two numbers",
  %{
    type: :OBJECT,
    properties: %{
      "a" => %{type: :NUMBER, description: "First number"},
      "b" => %{type: :NUMBER, description: "Second number"}
    },
    required: ["a", "b"]
  },
  fn %{"a" => a, "b" => b} -> {:ok, a + b} end
)

# Complex tool with nested objects
Work.AltarTools.register(
  "search_documents",
  "Search document corpus with filters",
  %{
    type: :OBJECT,
    properties: %{
      "query" => %{type: :STRING, description: "Search query"},
      "limit" => %{type: :NUMBER, description: "Max results"},
      "filters" => %{
        type: :OBJECT,
        properties: %{
          "category" => %{type: :STRING},
          "date_range" => %{
            type: :OBJECT,
            properties: %{
              "start" => %{type: :STRING},
              "end" => %{type: :STRING}
            }
          }
        }
      }
    },
    required: ["query"]
  },
  &MyApp.Search.search/1
)
```

### Tool Function Requirements

Tool functions must:
- Accept a single argument (map of parameters)
- Return `{:ok, result}` on success
- Return `{:error, reason}` on failure

Example:

```elixir
defmodule MyApp.CNS.Proposer do
  def extract(%{"doc_id" => doc_id} = args) do
    max_claims = Map.get(args, "max_claims", 10)

    case fetch_document(doc_id) do
      {:ok, document} ->
        claims = extract_claims(document, max_claims)
        {:ok, %{claims: claims, doc_id: doc_id}}

      {:error, reason} ->
        {:error, "Failed to extract claims: #{reason}"}
    end
  end
end
```

### Submitting Tool Call Jobs

Create and submit jobs with the `:tool_call` kind:

```elixir
job = Work.Job.new(
  kind: :tool_call,
  tenant_id: "acme",
  namespace: "default",
  priority: :interactive,
  payload: %{
    tool_name: "proposer_extract",
    args: %{
      doc_id: "doc_123",
      max_claims: 5
    }
  }
)

{:ok, submitted_job} = Work.submit(job)

# Wait for completion
case Work.get(submitted_job.id) do
  {:ok, %{status: :succeeded, result: result}} ->
    IO.inspect(result)

  {:ok, %{status: :failed, error: error}} ->
    IO.puts("Job failed: #{error.message}")
end
```

### Tool Management

```elixir
# Check if tool exists
if Work.AltarTools.registered?("calculator_add") do
  IO.puts("Tool is available")
end
```

### CNS Integration Example

For CNS (Critic-Network Synthesis) agents:

```elixir
# Register Proposer agent tool
Work.AltarTools.register(
  "cns_proposer",
  "Extract structured claims from documents",
  %{
    type: :OBJECT,
    properties: %{
      "document" => %{type: :STRING, description: "Source document"},
      "schema" => %{type: :STRING, description: "Target schema"}
    },
    required: ["document"]
  },
  &CNS.Agents.Proposer.extract/1
)

# Register Antagonist agent tool
Work.AltarTools.register(
  "cns_antagonist",
  "Find contradictions in claim networks",
  %{
    type: :OBJECT,
    properties: %{
      "sno_graph" => %{type: :OBJECT, description: "SNO graph"},
      "beta1_threshold" => %{type: :NUMBER, description: "β₁ threshold"}
    },
    required: ["sno_graph"]
  },
  &CNS.Agents.Antagonist.critique/1
)

# Execute dialectical workflow
proposer_job = Work.Job.new(
  kind: :tool_call,
  tenant_id: "research",
  namespace: "cns",
  priority: :batch,
  payload: %{
    tool_name: "cns_proposer",
    args: %{document: document_text, schema: "scifact"}
  }
)

{:ok, proposer_result} = Work.submit(proposer_job)
```

## Integration Examples

### Crucible Experiments

```elixir
defmodule Crucible.Pipeline.Runner do
  def run_stage(experiment, stage, context) do
    job = Work.Job.new(
      kind: :experiment_step,
      tenant_id: context[:tenant_id],
      namespace: experiment.id,
      priority: :batch,
      payload: %{
        experiment_id: experiment.id,
        stage_name: stage.name,
        input_context: context
      },
      constraints: Work.Constraints.new(
        concurrency_group: "experiment:#{experiment.id}"
      )
    )

    Work.submit(job)
  end
end
```

### ALTAR Tool Calls

```elixir
defmodule ALTAR.GRID do
  def dispatch(tool, input, opts \\ []) do
    job = Work.Job.new(
      kind: :tool_call,
      tenant_id: opts[:tenant_id] || "default",
      namespace: opts[:namespace] || "default",
      priority: opts[:priority] || :interactive,
      payload: %{
        tool_id: tool.id,
        function_name: tool.name,
        arguments: input
      },
      resources: translate_resources(tool.resources)
    )

    Work.submit(job)
  end
end
```

## Roadmap

- [ ] Persistent storage backend (Postgres/Ecto)
- [ ] Tenant quotas and rate limiting
- [x] ALTAR backend integration
- [ ] Modal.com backend adapter
- [ ] Ray backend adapter
- [ ] Job dependencies and DAGs
- [ ] Concurrency groups
- [ ] Cost tracking and budgets
- [ ] Web UI for monitoring

## Contributing

This is part of the North-Shore-AI platform. Contributions welcome!

## License

MIT License - see LICENSE file for details

## Links

- [GitHub](https://github.com/North-Shore-AI/work)
- [Documentation](https://hexdocs.pm/work)
- [Changelog](CHANGELOG.md)
- [North-Shore-AI Platform](https://github.com/North-Shore-AI)

