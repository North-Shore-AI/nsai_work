# Examples

Runnable examples demonstrating NsaiWork features. Each script is self-contained and uses the Local backend.

## Prerequisites

```bash
mix deps.get && mix compile
```

## Running Examples

Run any example with:

```bash
mix run examples/basic_job.exs
```

Or run all examples:

```bash
./examples/run_all.sh
```

## Example Index

### `basic_job.exs`

Create jobs, submit them, check status, list by tenant, and view stats. Covers the core `NsaiWork.submit/1`, `NsaiWork.get/1`, `NsaiWork.list/2`, and `NsaiWork.stats/0` API.

### `priority_queues.exs`

Submit jobs at all four priority levels (realtime, interactive, batch, offline) and observe how they route through the scheduler's priority queues. Shows queue statistics and namespace filtering.

### `custom_backend.exs`

Implement a custom `NsaiWork.Backend` behaviour inline. Demonstrates the `execute/1` and `supports?/1` callbacks, backend registration with the Executor, and how job kinds control routing.

### `telemetry_events.exs`

Attach telemetry handlers for job lifecycle, scheduler, and queue events. Watch events fire in real time as a job moves through the system. Covers `:telemetry.attach_many/4` and handler cleanup.

### `retry_policies.exs`

Compare backoff strategies (exponential, linear, constant), demonstrate jitter effects, and show how `NsaiWork.Constraints` controls retry behavior. Uses `Constraints.retry_delay/2` and `Constraints.can_retry?/2`.
