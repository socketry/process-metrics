# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

module Process
	module Metrics
		# Linux implementation of per-process memory metrics using `/proc/[pid]/smaps` or `/proc/[pid]/smaps_rollup`, and `/proc/[pid]/stat` for fault counters.
		# Prefers smaps_rollup when readable (single summary); otherwise falls back to full smaps and counts maps from /proc/[pid]/maps.
		class Memory::Linux
			# Extract minor and major page fault counters from `/proc/[pid]/stat` (proc(5): fields 10=minflt, 12=majflt) and assign to usage.
			# @parameter pid [Integer] Process ID.
			# @parameter usage [Memory] Memory instance to populate with minor_faults and major_faults.
			def self.capture_faults(pid, usage)
				stat_content = File.read("/proc/#{pid}/stat")
				# The comm field can contain spaces and parentheses; find the closing ')':
				closing_paren_index = stat_content.rindex(")")
				return unless closing_paren_index
				fields = stat_content[(closing_paren_index + 2)..].split(/\s+/)
				# proc(5): field 10=minflt, 12=majflt; our fields array is 0-indexed from field 3.
				usage.minor_faults = fields[10-3].to_i
				usage.major_faults = fields[12-3].to_i
			rescue
				# Ignore.
			end
			
			# Mapping from smaps/smaps_rollup line names to Memory struct members (values in kB, converted to bytes when parsing).
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
				
				# Capture memory usage from /proc/[pid]/smaps_rollup and /proc/[pid]/maps. Optionally fill fault counters from /proc/[pid]/stat.
				# @parameter pid [Integer] Process ID.
				# @parameter faults [Boolean] Whether to capture minor_faults and major_faults (default: true).
				# @returns [Memory | Nil]
				def self.capture(pid, faults: true, **options)
					File.open("/proc/#{pid}/smaps_rollup") do |file|
						usage = Memory.zero
						file.each_line do |line|
							if /(?<name>.*?):\s+(?<value>\d+) kB/ =~ line
								if key = SMAP[name]
									# Convert from kilobytes to bytes:
									usage[key] += value.to_i * 1024
								end
							end
						end
						
						usage.map_count += File.readlines("/proc/#{pid}/maps").size
						
						# Also capture fault counters if requested:
						if faults
							self.capture_faults(pid, usage)
						end
						
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
				
				# Capture memory usage from /proc/[pid]/smaps (and map count from VmFlags) and /proc/[pid]/maps. Optionally fill fault counters from /proc/[pid]/stat.
				# @parameter pid [Integer] Process ID.
				# @parameter faults [Boolean] Whether to capture minor_faults and major_faults (default: true).
				# @returns [Memory | Nil]
				def self.capture(pid, faults: true, **options)
					File.open("/proc/#{pid}/smaps") do |file|
						usage = Memory.zero
						file.each_line do |line|
							# The format of this is fixed according to:
							# https://github.com/torvalds/linux/blob/351c8a09b00b5c51c8f58b016fffe51f87e2d820/fs/proc/task_mmu.c#L804-L814
							if /(?<name>.*?):\s+(?<value>\d+) kB/ =~ line
								if key = SMAP[name]
									# Convert from kilobytes to bytes:
									usage[key] += value.to_i * 1024
								end
							elsif /VmFlags:\s+(?<flags>.*)/ =~ line
								# It should be possible to extract the number of fibers and each fiber's memory usage.
								# flags = flags.split(/\s+/)
								usage.map_count += 1
							end
						end
						
						# Also capture fault counters if requested:
						if faults
							self.capture_faults(pid, usage)
						end
						
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
	end
end

# Wire Memory.capture and Memory.supported? to this implementation when smaps or smaps_rollup is readable.
if Process::Metrics::Memory::Linux.supported?
	class << Process::Metrics::Memory
		# Whether memory capture is supported on this platform.
		# @returns [Boolean] True if /proc/[pid]/smaps or smaps_rollup is readable.
		def supported?
			true
		end
		
		# Capture memory metrics for a process.
		# @parameter pid [Integer] The process ID.
		# @parameter faults [Boolean] Whether to capture fault counters (default: true).
		# @parameter options [Hash] Additional options.
		# @returns [Memory | Nil] A Memory instance with captured metrics.
		def capture(...)
			Process::Metrics::Memory::Linux.capture(...)
		end
	end
end
