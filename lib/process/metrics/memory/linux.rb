# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Process
	module Metrics
		# Linux implementation of memory metrics using `/proc/[pid]/smaps` and `/proc/[pid]/stat`.
		class Memory::Linux
			# Threshold for distinguishing actual memory limits from "unlimited" sentinel values in cgroups v1.
			# 
			# In cgroups v1, when memory.limit_in_bytes is set to unlimited (by writing -1),
			# the kernel stores a very large sentinel value close to 2^63 (approximately 9,223,372,036,854,771,712 bytes).
			# Since no real system would have 1 exabyte (2^60 bytes) of RAM, any value >= this threshold
			# indicates an "unlimited" configuration and should be treated as if no limit is set.
			#
			# This allows us to distinguish between:
			# - Actual container memory limits: typically in GB-TB range (< 1 EB)
			# - Unlimited sentinel values: near 2^63 (>> 1 EB)
			#
			# Reference: https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt
			CGROUP_V1_UNLIMITED_THRESHOLD = 2**60 # ~1 exabyte
			
			# Extract minor/major page fault counters from `/proc/[pid]/stat` and assign to usage.
			# @parameter pid [Integer] The process ID.
			# @parameter usage [Memory] The Memory instance to populate with fault counters.
			def self.capture_faults(pid, usage)
				stat = File.read("/proc/#{pid}/stat")
				# The comm field can contain spaces and parentheses; find the closing ')':
				rparen_index = stat.rindex(")")
				return unless rparen_index
				fields = stat[(rparen_index+2)..-1].split(/\s+/)
				# proc(5): field 10=minflt, 12=majflt; our fields array is 0-indexed from field 3.
				usage.minor_faults = fields[10-3].to_i
				usage.major_faults = fields[12-3].to_i
			rescue
				# Ignore.
			end
			
			# Determine the total memory size in kilobytes. This is the maximum amount of memory that can be used by the current process. If running in a container, this may be limited by the container runtime (e.g. cgroups).
			#
			# @returns [Integer] The total memory size in kilobytes.
			def self.total_size
				# Check for Kubernetes/cgroup memory limit first (cgroups v2):
				if File.exist?("/sys/fs/cgroup/memory.max")
					limit = File.read("/sys/fs/cgroup/memory.max").strip
					# "max" means unlimited, fall through to other methods:
					if limit != "max"
						return limit.to_i / 1024
					end
				end
				
				# Check for Kubernetes/cgroup memory limit (cgroups v1):
				if File.exist?("/sys/fs/cgroup/memory/memory.limit_in_bytes")
					limit = File.read("/sys/fs/cgroup/memory/memory.limit_in_bytes").strip.to_i
					# A very large number means unlimited, fall through:
					if limit > 0 && limit < CGROUP_V1_UNLIMITED_THRESHOLD
						return limit / 1024
					end
				end
				
				# Fall back to Linux system memory detection:
				if File.exist?("/proc/meminfo")
					File.foreach("/proc/meminfo") do |line|
						if /MemTotal:\s*(?<total>\d+)\s*kB/ =~ line
							return total.to_i
						end
					end
				end
			end
			
			# The fields that will be extracted from the `smaps` data.
			SMAP = {
				"Rss" => :resident_size,
				"Pss" => :proportional_size,
				"Shared_Clean" => :shared_clean_size,
				"Shared_Dirty" => :shared_dirty_size,
				"Private_Clean" => :private_clean_size,
				"Private_Dirty" => :private_dirty_size,
				"Referenced" => :referenced_size,
				"Anonymous" => :anonymous_size,
				"Swap" => :swap_size,
				"SwapPss" => :proportional_swap_size,
			}
			
			if File.readable?("/proc/self/smaps_rollup")
				# Whether the memory usage can be captured on this system.
				def self.supported?
					true
				end
				
				# Capture memory usage for the given process IDs.
				def self.capture(pid, **options)
					File.open("/proc/#{pid}/smaps_rollup") do |file|
						usage = Memory.zero
						
						file.each_line do |line|
							if /(?<name>.*?):\s+(?<value>\d+) kB/ =~ line
								if key = SMAP[name]
									usage[key] += value.to_i
								end
							end
						end
						
						usage.map_count += File.readlines("/proc/#{pid}/maps").size
						# Also capture fault counters:
						self.capture_faults(pid, usage)
						
						return usage
					end
				rescue Errno::ENOENT, Errno::ESRCH, Errno::EACCES
					# Process doesn't exist or we can't access it.
					return nil
				end
			elsif File.readable?("/proc/self/smaps")
				# Whether the memory usage can be captured on this system.
				def self.supported?
					true
				end
				
				# Capture memory usage for the given process IDs.
				def self.capture(pid, **options)
					File.open("/proc/#{pid}/smaps") do |file|
						usage = Memory.zero
						
						file.each_line do |line|
							# The format of this is fixed according to:
							# https://github.com/torvalds/linux/blob/351c8a09b00b5c51c8f58b016fffe51f87e2d820/fs/proc/task_mmu.c#L804-L814
							if /(?<name>.*?):\s+(?<value>\d+) kB/ =~ line
								if key = SMAP[name]
									usage[key] += value.to_i
								end
							elsif /VmFlags:\s+(?<flags>.*)/ =~ line
								# It should be possible to extract the number of fibers and each fiber's memory usage.
								# flags = flags.split(/\s+/)
								usage.map_count += 1
							end
						end
						
						# Also capture fault counters:
						self.capture_faults(pid, usage)
						
						return usage
					end
				rescue Errno::ENOENT, Errno::ESRCH, Errno::EACCES
					# Process doesn't exist or we can't access it.
					return nil
				end
			else
				def self.supported?
					false
				end
			end
		end
		
		if Memory::Linux.supported?
			class << Memory
				# Whether memory capture is supported on this platform.
				# @returns [Boolean] True if /proc/[pid]/smaps or smaps_rollup is readable.
				def supported?
					return true
				end
				
				# Get total system memory size.
				# @returns [Integer] Total memory in kilobytes.
				def total_size
					return Memory::Linux.total_size
				end
				
				# Capture memory metrics for a process.
				# @parameter pid [Integer] The process ID.
				# @parameter options [Hash] Additional options.
				# @returns [Memory] A Memory instance with captured metrics.
				def capture(...)
					return Memory::Linux.capture(...)
				end
			end
		end
	end
end
