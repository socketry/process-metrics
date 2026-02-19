# Process::Metrics

Extract performance and memory metrics from running processes.

![Command Line Example](command-line.png)

[![Development Status](https://github.com/socketry/process-metrics/workflows/Test/badge.svg)](https://github.com/socketry/process-metrics/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/process-metrics/) for more details.

  - [Getting Started](https://socketry.github.io/process-metrics/guides/getting-started/index) - This guide explains how to use the `process-metrics` gem to collect and analyze process metrics including processor and memory utilization.

## Releases

Please see the [project releases](https://socketry.github.io/process-metrics/releases/index) for all releases.

### v0.10.0

  - **Host::Memory**: New per-host struct `Process::Metrics::Host::Memory` with `total`, `used`, `free`, `swap_total`, `swap_used` (all bytes). Use `Host::Memory.capture` to get a snapshot; `.supported?` indicates platform support.

### v0.9.0

  - `Process::Metrics::Memory.total_size` takes into account cgroup limits.
  - On Linux, capturing faults is optional, controlled by `capture(faults: true/false)`.
  - Report all sizes in bytes for consistency.

### v0.8.0

  - Kill `ps` before waiting to avoid hanging when using the process-status backend.
  - Ignore `Errno::EACCES` when reading process information.
  - Cleaner process management for the `ps`-based capture path.

### v0.7.0

  - Be more proactive about returning nil if memory capture failed.

### v0.6.1

  - Handle `Errno::ESRCH: No such process @ io_fillbuf - fd:xxx /proc/xxx/smaps_rollup` by ignoring it.

### v0.6.0

  - Add support for major and minor page faults on Linux: `Process::Metrics::Memory#major_faults` and `#minor_faults`. Unfortunately these metrics are not available on Darwin (macOS).

### v0.5.1

  - Fixed Linux memory usage capture to correctly read memory statistics.

### v0.5.0

  - Added `--total-memory` option for scaling memory usage graphs, allowing users to set custom total memory values.
  - Improved support for proportional memory usage (PSS).
  - Exposed total system memory information.

### v0.4.0

  - Fixed command formatting in output display.
  - Modernized codebase to use current Ruby conventions.
  - Improved Darwin (macOS) support with better platform-specific handling.

### v0.3.0

  - Added support for `smaps_rollup` on Linux for more efficient memory statistics collection.
  - Fixed `smaps_rollup` detection (corrected file path).
  - Removed `sz` metric (not supported on Darwin).
  - Expanded test coverage.
  - Improved documentation with better syntax highlighting and fixed links.
  - Avoided abbreviations in naming conventions for better code clarity.
  - Added missing dependencies: `bake-test-external` and `json` gem.
  - Added summary lines for PSS (Proportional Set Size) and USS (Unique Set Size).

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
