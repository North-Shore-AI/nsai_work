# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-12-06

### Added

- Initial release of NSAI.Work unified job scheduler
- Core IR structs:
  - `Work.Job` - Universal job representation
  - `Work.Resources` - Resource requirements
  - `Work.Constraints` - Scheduling constraints and retry policies
  - `Work.Error` - Standardized error representation
- Priority queue system:
  - Four priority levels (realtime, interactive, batch, offline)
  - FIFO ordering within priority levels
  - `Work.Queue` GenServer for queue management
- Job scheduling:
  - `Work.Scheduler` with admission control
  - Resource-aware job dispatch
  - Multi-tenant support
- Job execution:
  - `Work.Executor` with backend delegation
  - Retry policies with configurable backoff
  - Job lifecycle management
- Storage and indexing:
  - `Work.Registry` ETS-based job storage
  - Indexes by tenant, status, namespace
- Backend system:
  - `Work.Backend` behaviour for pluggable backends
  - `Work.Backends.Local` for BEAM process execution
  - `Work.Backends.Mock` for testing
- Observability:
  - `Work.Telemetry` with comprehensive event instrumentation
  - Job lifecycle events
  - Scheduler and queue events
  - Built-in console logger
- Public API:
  - `Work.submit/1` - Submit jobs
  - `Work.get/1` - Get job by ID
  - `Work.list/2` - List jobs by tenant
  - `Work.stats/0` - Get system statistics
- Documentation:
  - Comprehensive README with examples
  - API documentation with doctests
  - Architecture diagrams
  - Integration examples for Crucible and ALTAR

### Infrastructure

- OTP supervision tree
- Mix project configuration
- Test suite with ExUnit
- Code quality tools (Credo, Dialyxir)
- Continuous integration setup

[Unreleased]: https://github.com/North-Shore-AI/work/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/North-Shore-AI/work/releases/tag/v0.1.0
