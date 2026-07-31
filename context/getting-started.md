# Getting Started

This guide explains how to use the `process-metrics` gem to collect and analyze process metrics including processor and memory utilization.

## Installation

Add the gem to your project:

``` bash
$ bundle add process-metrics
```

Or, if you prefer, install it globally:

``` bash
$ gem install process-metrics
```

## Core Concepts

The `process-metrics` gem provides a simple interface to collect and analyze process metrics.

- {ruby Process::Metrics::General} is the main entry point for process metrics. Use {ruby Process::Metrics::General.capture} to collect metrics for one or more processes.
- {ruby Process::Metrics::Memory} provides additional methods for collecting memory metrics when the host operating system provides the necessary information.

## Usage

To collect process metrics, use the {ruby Process::Metrics::General.capture} method:

``` ruby
Process::Metrics::General.capture(pid: Process.pid)
# => 
# {3517456=>
#   #<struct Process::Metrics::General
#    process_id=3517456,
#    parent_process_id=3517432,
#    process_group_id=3517456,
#    processor_utilization=0.0,
#    virtual_size=445768278528,
#    resident_size=20348928,
#    processor_time=0.05,
#    elapsed_time=2.0,
#    command="irb",
#    memory=
#     #<struct Process::Metrics::Memory
#      map_count=193,
#      resident_size=31289344,
#      proportional_size=26288128,
#      shared_clean_size=5128192,
#      shared_dirty_size=0,
#      private_clean_size=5304320,
#      private_dirty_size=20856832,
#      referenced_size=31281152,
#      anonymous_size=20865024,
#      swap_size=0,
#      proportional_swap_size=0,
#      minor_faults=0,
#      major_faults=0>>}
```

If you want to capture a tree of processes, you can specify the `ppid:` option instead.

### Fields

The {ruby Process::Metrics::General} struct contains the following fields:

- `process_id` - Process ID, a unique identifier for the process.
- `parent_process_id` - Parent Process ID, the process ID of the process that started this process.
- `process_group_id` - Process Group ID, the process group ID of the process, which can be shared by multiple processes.
- `processor_utilization` - Processor Utilization (%), the percentage of CPU time used by the process (over a system-specific duration).
- `total_size` - Memory Size (bytes), the total size of the process's memory space (usually over-estimated as it doesn't take into account shared memory).
- `resident_size` - Resident (Set) Size (bytes), the amount of physical memory used by the process.
- `processor_time` - CPU Time (s), the amount of CPU time used by the process.
- `elapsed_time` - Elapsed Time (s), the amount of time the process has been running.
- `command` - Command Name, the name of the command that started the process.

The {ruby Process::Metrics::Memory} struct contains the following fields:

- `map_count` - Number of Memory Mappings, e.g. number of thread stacks, fiber stacks, shared libraries, memory mapped files, etc.
- `resident_size` - Resident Memory Size (bytes), the amount of physical memory used by the process.
- `proportional_size` - Proportional Memory Size (bytes), the amount of memory that the process is using, taking into account shared memory.
- `shared_clean_size` - Shared Clean Memory Size (bytes), the amount of shared memory that is clean (not modified).
- `shared_dirty_size` - Shared Dirty Memory Size (bytes), the amount of shared memory that is dirty (modified).
- `private_clean_size` - Private Clean Memory Size (bytes), the amount of private memory that is clean (not modified).
- `private_dirty_size` - Private Dirty Memory Size (bytes), the amount of private memory that is dirty (modified).
- `referenced_size` - Referenced Memory Size (bytes), active page-cache that isn't going to be reclaimed any time soon.
- `anonymous_size` - Anonymous Memory Size (bytes), mapped memory that isn't backed by a file.
- `swap_size` - Swap Memory Size (bytes), the amount of memory that has been swapped to disk.
- `proportional_swap_size` - Proportional Swap Memory Size (bytes), the amount of memory that has been swapped to disk, excluding shared memory.

In general, the interpretation of these fields is operating system specific. At best, they provide a rough estimate of the process's memory usage, but you should consult the documentation for your operating system for more details on exactly what each field represents.
