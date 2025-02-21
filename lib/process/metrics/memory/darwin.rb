# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Process
	module Metrics
		class Memory::Darwin
			VMMAP = "/usr/bin/vmmap"
			
			# Whether the memory usage can be captured on this system.
			def self.supported?
				File.executable?(VMMAP)
			end
			
			# @returns [Numeric] Total memory size in kilobytes.
			def self.total_size
				# sysctl hw.memsize
				IO.popen(["sysctl", "hw.memsize"], "r") do |io|
					io.each_line do |line|
						if line =~ /hw.memsize: (\d+)/
							return $1.to_i / 1024
						end
					end
				end
			end
			
			# Parse a size string into kilobytes.
			def self.parse_size(string)
				return 0 unless string
				
				case string.strip
				when /([\d\.]+)K/i then ($1.to_f).round
				when /([\d\.]+)M/i then ($1.to_f * 1024).round
				when /([\d\.]+)G/i then ($1.to_f * 1024 * 1024).round
				else (string.to_f / 1024).ceil
				end
			end
			
			LINE = /\A
				\s*
				(?<region_name>.+?)\s+
				(?<start_address>[0-9a-fA-F]+)-(?<end_address>[0-9a-fA-F]+)\s+
				\[\s*(?<virtual_size>[\d\.]+[KMG]?)\s+(?<resident_size>[\d\.]+[KMG]?)\s+(?<dirty_size>[\d\.]+[KMG]?)\s+(?<swap_size>[\d\.]+[KMG]?)\s*\]\s+
				(?<permissions>[rwx\-\/]+)\s+
				SM=(?<sharing_mode>\w+)
			/x
			
			# Capture memory usage for the given process IDs.
			def self.capture(pid, count: 1, **options)
				usage = Memory.zero
				
				IO.popen(["vmmap", pid.to_s], "r") do |io|
					io.each_line do |line|
						if match = LINE.match(line)
							virtual_size = parse_size(match[:virtual_size])
							resident_size = parse_size(match[:resident_size])
							dirty_size = parse_size(match[:dirty_size])
							swap_size = parse_size(match[:swap_size])
							
							# Update counts
							usage.map_count += 1
							usage.resident_size += resident_size
							usage.swap_size += swap_size
							
							# Private vs. Shared memory
							# COW=copy_on_write PRV=private NUL=empty ALI=aliased 
							# SHM=shared ZER=zero_filled S/A=shared_alias
							case match[:sharing_mode]
							when "PRV"
								usage.private_clean_size += resident_size - dirty_size
								usage.private_dirty_size += dirty_size
							when "COW", "SHM"
								usage.shared_clean_size += resident_size - dirty_size
								usage.shared_dirty_size += dirty_size
							end
							
							# Anonymous memory: no region detail path or special names
							if match[:region_name] =~ /MALLOC|VM_ALLOCATE|Stack|STACK|anonymous/
								usage.anonymous_size += resident_size
							end
						end
					end
				end
				
				# Darwin does not expose proportional memory usage, so we guess based on the number of processes. Yes, this is a terrible hack, but it's the most reasonable thing to do given the constraints:
				usage.proportional_size = usage.resident_size / count
				usage.proportional_swap_size = usage.swap_size / count
				
				return usage
			end
		end
		
		if Memory::Darwin.supported?
			class << Memory
				def supported?
					return true
				end
				
				def total_size
					return Memory::Darwin.total_size
				end
				
				def capture(...)
					return Memory::Darwin.capture(...)
				end
			end
		end
	end
end
