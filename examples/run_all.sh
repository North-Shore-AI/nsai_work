#!/usr/bin/env bash
#
# Run all NsaiWork examples in sequence.
#
# Usage: ./examples/run_all.sh

set -e

cd "$(dirname "$0")/.."

examples=(
  basic_job.exs
  priority_queues.exs
  custom_backend.exs
  telemetry_events.exs
  retry_policies.exs
)

for example in "${examples[@]}"; do
  echo ""
  echo "=========================================="
  echo " Running: examples/$example"
  echo "=========================================="
  echo ""
  mix run "examples/$example"
done

echo ""
echo "All examples completed."
