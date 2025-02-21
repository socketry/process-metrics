# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

module Process
	module Metrics
		class Memory::Linux
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
			
			if File.readable?('/proc/self/smaps_rollup')
				# Whether the memory usage can be captured on this system.
				def self.supported?
					true
				end
			
				# Capture memory usage for the given process IDs.
				def self.capture(pids)
					usage = Memory.zero
					
					pids.each do |pid|
						File.foreach("/proc/#{pid}/smaps_rollup") do |line|
							if /(?<name>.*?):\s+(?<value>\d+) kB/ =~ line
								if key = SMAP[name]
									usage[key] += value.to_i
								end
							end
						end
						
						usage.map_count += File.readlines("/proc/#{pid}/maps").size
					rescue Errno::ENOENT => error
						# Ignore.
					end
					
					return usage
				end
			elsif File.readable?('/proc/self/smaps')
				# Whether the memory usage can be captured on this system.
				def self.supported?
					true
				end
				
				# Capture memory usage for the given process IDs.
				def self.capture(pids)
					usage = Memory.zero
					
					pids.each do |pid|
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
				def supported?
					return true
				end
				
				def capture(pids)
					return Memory::Linux.capture(pids)
				end
			end
		end
	end
end
