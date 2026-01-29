# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-01-28

### Added

- Initial release of NsaiWork unified job scheduler
- Protocol-first job scheduling with `NsaiWork.Job` IR struct
- Priority queue implementation with `NsaiWork.Queue`
- Resource-aware scheduling via `NsaiWork.Scheduler`
- Pluggable backend execution (`Local`, `Altar`, `Mock`)
- ALTAR backend integration for tool call execution
- Multi-tenant support with `NsaiWork.Registry`
- Telemetry instrumentation via `NsaiWork.Telemetry`
- OTP supervision tree with `NsaiWork.Supervisor`

[Unreleased]: https://github.com/North-Shore-AI/nsai_work/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/North-Shore-AI/nsai_work/releases/tag/v0.1.0
