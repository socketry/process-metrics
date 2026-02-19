# Releases

## Unreleased

  - **Host::Memory**: New per-host struct `Process::Metrics::Host::Memory` with `total`, `used`, `free`, `swap_total`, `swap_used` (all bytes). Use `Host::Memory.capture` to get a snapshot; `.supported?` indicates platform support.

## v0.9.0

  - `Process::Metrics::Memory.total_size` takes into account cgroup limits.
  - On Linux, capturing faults is optional, controlled by `capture(faults: true/false)`.
  - Report all sizes in bytes for consistency.

## v0.7.0

  - Be more proactive about returning nil if memory capture failed.

## v0.6.1

  - Handle `Errno::ESRCH: No such process @ io_fillbuf - fd:xxx /proc/xxx/smaps_rollup` by ignoring it.

## v0.6.0

  - Add support for major and minor page faults on Linux: `Process::Metrics::Memory#major_faults` and `#minor_faults`. Unfortunately these metrics are not available on Darwin (macOS).

## v0.5.1

  - Fixed Linux memory usage capture to correctly read memory statistics.

## v0.5.0

  - Added `--total-memory` option for scaling memory usage graphs, allowing users to set custom total memory values.
  - Improved support for proportional memory usage (PSS).
  - Exposed total system memory information.

## v0.4.0

  - Fixed command formatting in output display.
  - Modernized codebase to use current Ruby conventions.
  - Improved Darwin (macOS) support with better platform-specific handling.

## v0.3.0

  - Added support for `smaps_rollup` on Linux for more efficient memory statistics collection.
  - Fixed `smaps_rollup` detection (corrected file path).
  - Removed `sz` metric (not supported on Darwin).
  - Expanded test coverage.
  - Improved documentation with better syntax highlighting and fixed links.
  - Avoided abbreviations in naming conventions for better code clarity.
  - Added missing dependencies: `bake-test-external` and `json` gem.
  - Added summary lines for PSS (Proportional Set Size) and USS (Unique Set Size).

## v0.2.1

  - Added missing dependency to gemspec.
  - Added example of command line usage to documentation.
  - Renamed `rsz` to `rss` (Resident Set Size) for consistency across Darwin and Linux platforms.

## v0.2.0

  - Added `process-metrics` command line interface for monitoring processes.
  - Implemented structured data using Ruby structs for better performance and clarity.
  - Added documentation about PSS (Proportional Set Size) and USS (Unique Set Size) metrics.

## v0.1.1

  - Removed `Gemfile.lock` from version control.
  - Fixed process metrics to exclude the `ps` command itself from measurements.
  - Fixed documentation formatting issues.

## v0.1.0

  - Initial release with support for process and memory metrics on Linux and Darwin (macOS).
  - Support for selecting processes based on PID or PPID (process group).
  - Implementation of memory statistics collection using `/proc` filesystem on Linux.
  - Better handling of process hierarchies.
  - Support for older Ruby versions.
