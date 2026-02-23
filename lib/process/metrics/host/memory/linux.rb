# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require_relative "linux/cgroup_v2"
require_relative "linux/cgroup_v1"
require_relative "linux/meminfo"

module Process
	module Metrics
		module Host
			# Linux host memory: tries cgroup v2, then cgroup v1, then /proc/meminfo.
			module Memory::Linux
				DEFAULT_CGROUP_ROOT = "/sys/fs/cgroup"

				def self.capture(cgroup_root: DEFAULT_CGROUP_ROOT)
					if Memory::Linux::CgroupV2.supported?(cgroup_root)
						if capture = Memory::Linux::CgroupV2.new(cgroup_root: cgroup_root).capture
							return capture
						end
					end
					
					if Memory::Linux::CgroupV1.supported?(cgroup_root)
						if capture = Memory::Linux::CgroupV1.new(cgroup_root: cgroup_root).capture
							return capture
						end
					end
					
					return Memory::Linux::Meminfo.new.capture if Memory::Linux::Meminfo.supported?
				end
			end
		end
	end
end

# Wire Host::Memory to this implementation on Linux.
class << Process::Metrics::Host::Memory
	def capture
		Process::Metrics::Host::Memory::Linux.capture
	end
	
	def supported?
		File.exist?("/proc/meminfo")
	end
end
