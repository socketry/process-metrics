# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require 'json'

module Process
	module Metrics
		class Memory < Struct.new(:map_count, :resident_size, :proportional_size, :shared_clean_size, :shared_dirty_size, :private_clean_size, :private_dirty_size, :referenced_size, :anonymous_size, :swap_size, :proportional_swap_size)
			
			alias as_json to_h
			
			def to_json(*arguments)
				as_json.to_json(*arguments)
			end
			
			def total_size
				self.resident_size + self.swap_size
			end
			
			# The unique set size, the size of completely private (unshared) data.
			def unique_size
				self.private_clean_size + self.private_dirty_size
			end
			
			MAP = {
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
				def self.supported?
					true
				end
				
				def self.capture(pids)
					usage = self.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
					
					pids.each do |pid|
						File.foreach("/proc/#{pid}/smaps_rollup") do |line|
							if /(?<name>.*?):\s+(?<value>\d+) kB/ =~ line
								if key = MAP[name]
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
				def self.supported?
					true
				end
				
				def self.capture(pids)
					usage = self.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
					
					pids.each do |pid|
						File.foreach("/proc/#{pid}/smaps") do |line|
							# The format of this is fixed according to:
							# https://github.com/torvalds/linux/blob/351c8a09b00b5c51c8f58b016fffe51f87e2d820/fs/proc/task_mmu.c#L804-L814
							if /(?<name>.*?):\s+(?<value>\d+) kB/ =~ line
								if key = MAP[name]
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
				
				def self.capture(pids)
					return self.new
				end
			end
		end
	end
end
