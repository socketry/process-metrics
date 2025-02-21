# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

module Process
	module Metrics
		class Memory::Darwin
			VMMAP = "/usr/bin/vmmap"
			
			# Whether the memory usage can be captured on this system.
			def self.supported?
				File.executable?(VMMAP)
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
			def self.capture(pids)
				usage = Memory.zero
				
				pids.each do |pid|
					IO.popen(["vmmap", pid.to_s], 'r') do |io|
						io.each_line do |line|
							if match = LINE.match(line)
								virtual_size = parse_size(match[:virtual_size])
								resident_size = parse_size(match[:resident_size])
								dirty_size = parse_size(match[:dirty_size])
								swap_size = parse_size(match[:swap_size])
								
								# puts [match[:region_name], virtual_size, resident_size, dirty_size, swap_size, match[:permissions], match[:sharing_mode]].join(",")
								
								# Update counts
								usage.map_count += 1
								usage.resident_size += resident_size
								usage.swap_size += swap_size
								
								# Private vs. Shared memory
								# COW=copy_on_write PRV=private NUL=empty ALI=aliased 
								# SHM=shared ZER=zero_filled S/A=shared_alias
								case match[:sharing_mode]
								when 'PRV'
									usage.private_clean_size += resident_size - dirty_size
									usage.private_dirty_size += dirty_size
								when 'COW', 'SHM'
									usage.shared_clean_size += resident_size - dirty_size
									usage.shared_dirty_size += dirty_size
								end
								
								# Anonymous memory: no region detail path or special names
								if match[:region_name] =~ /MALLOC|VM_ALLOCATE|Stack|STACK|anonymous/
									usage.anonymous_size += resident_size
								end
							# else
							# 	puts "Failed to match line: #{line}"
							end
						end
					end
				end
				
				# On Darwin, we cannot compute the proportional size, so we just set it to the resident size.
				usage.proportional_size = usage.resident_size
				usage.proportional_swap_size = usage.swap_size
				
				return usage
			end
		end
		
		if Memory::Darwin.supported?
			class << Memory
				def supported?
					return true
				end
				
				def capture(pids)
					return Memory::Darwin.capture(pids)
				end
			end
		end
	end
end
