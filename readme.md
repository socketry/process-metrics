# Process::Metrics

Extract performance and memory metrics from running processes.

![Command Line Example](command-line.png)

[![Development Status](https://github.com/socketry/process-metrics/workflows/Test/badge.svg)](https://github.com/socketry/process-metrics/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/process-metrics/) for more details.

  - [Getting Started](https://socketry.github.io/process-metrics/guides/getting-started/index) - This guide explains how to use the `process-metrics` gem to collect and analyze process metrics including processor and memory utilization.

## Releases

Please see the [project releases](https://socketry.github.io/process-metrics/releases/index) for all releases.

### v0.10.2

  - Add `Process::Metrics::Memory#private_size` for the sum of private (unshared) pages (Private\_Clean + Private\_Dirty); `#unique_size` is now an alias for `#private_size`.

### v0.10.1

  - Consistent use of `_size` suffix.

### v0.10.0

  - **Host::Memory**: New per-host struct `Process::Metrics::Host::Memory` with `total_size`, `used_size`, `free_size`, `swap_total_size`, `swap_used_size` (all bytes). Use `Host::Memory.capture` to get a snapshot; `.supported?` indicates platform support.

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
