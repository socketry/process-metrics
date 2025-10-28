# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Process
	module Metrics
		# Linux implementation of memory metrics using `/proc/[pid]/smaps` and `/proc/[pid]/stat`.
		class Memory::Linux
			# Extract minor/major page fault counters from `/proc/[pid]/stat` and assign to usage.
			# @parameter pid [Integer] The process ID.
			# @parameter usage [Memory] The Memory instance to populate with fault counters.
			def self.capture_faults(pid, usage)
				begin
					stat = File.read("/proc/#{pid}/stat")
					# The comm field can contain spaces and parentheses; find the closing ')':
					rparen_index = stat.rindex(")")
					return unless rparen_index
					fields = stat[(rparen_index+2)..-1].split(/\s+/)
					# proc(5): field 10=minflt, 12=majflt; our fields array is 0-indexed from field 3.
					usage.minor_faults = fields[10-3].to_i
					usage.major_faults = fields[12-3].to_i
				rescue Errno::ENOENT, Errno::EACCES
					# The process may have exited or permissions are insufficient; ignore.
				rescue => error
					# Be robust to unexpected formats; ignore errors silently.
				end
			end
			
			# @returns [Numeric] Total memory size in kilobytes.
			def self.total_size
				File.read("/proc/meminfo").each_line do |line|
					if /MemTotal:\s+(?<total>\d+) kB/ =~ line
						return total.to_i
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
					usage = Memory.zero
					
					begin
						File.foreach("/proc/#{pid}/smaps_rollup") do |line|
							if /(?<name>.*?):\s+(?<value>\d+) kB/ =~ line
								if key = SMAP[name]
									usage[key] += value.to_i
								end
							end
						end
						
						usage.map_count += File.readlines("/proc/#{pid}/maps").size
						# Also capture fault counters:
						self.capture_faults(pid, usage)
					rescue Errno::ENOENT => error
						# Ignore.
					end
					
					return usage
				end
			elsif File.readable?("/proc/self/smaps")
				# Whether the memory usage can be captured on this system.
				def self.supported?
					true
				end
				
				# Capture memory usage for the given process IDs.
				def self.capture(pid, **options)
					usage = Memory.zero
					
					begin
						File.foreach("/proc/#{pid}/smaps") do |line|
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
					rescue Errno::ENOENT => error
						# Ignore.
					end
					
					return usage
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
