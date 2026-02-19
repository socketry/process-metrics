# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

module Process
	module Metrics
		# Darwin (macOS) implementation of per-process memory metrics using vmmap(1).
		# Parses vmmap output for virtual/resident/dirty/swap per region and maps sharing mode (PRV, COW, SHM) to private/shared fields.
		class Memory::Darwin
			VMMAP = "/usr/bin/vmmap"
			
			# Whether the memory usage can be captured on this system.
			def self.supported?
				File.executable?(VMMAP)
			end
			
			# Parse a size string from vmmap (e.g. "4K", "1.5M", "2G") into bytes.
			# @parameter size_string [String | Nil]
			# @returns [Integer]
			def self.parse_size(size_string)
				return 0 unless size_string
				
				case size_string.strip
				when /([\d\.]+)K/i then ($1.to_f * 1024).round
				when /([\d\.]+)M/i then ($1.to_f * 1024 * 1024).round
				when /([\d\.]+)G/i then ($1.to_f * 1024 * 1024 * 1024).round
				else (size_string.to_f).ceil
				end
			end
			
			# Regex for vmmap region lines: region name, address range, [virtual resident dirty swap], permissions, SM=sharing_mode.
			LINE = /\A
				\s*
				(?<region_name>.+?)\s+
				(?<start_address>[0-9a-fA-F]+)-(?<end_address>[0-9a-fA-F]+)\s+
				\[\s*(?<virtual_size>[\d\.]+[KMG]?)\s+(?<resident_size>[\d\.]+[KMG]?)\s+(?<dirty_size>[\d\.]+[KMG]?)\s+(?<swap_size>[\d\.]+[KMG]?)\s*\]\s+
				(?<permissions>[rwx\-\/]+)\s+
				SM=(?<sharing_mode>\w+)
			/x
			
			# Capture memory usage by running vmmap for the given pid and summing region sizes. Proportional size is estimated as resident_size / count (Darwin has no PSS).
			# @parameter pid [Integer] Process ID.
			# @parameter count [Integer] Number of processes for proportional estimate (default: 1).
			# @returns [Memory | Nil]
			def self.capture(pid, count: 1, **options)
				IO.popen(["vmmap", pid.to_s], "r") do |io|
					usage = Memory.zero
					io.each_line do |line|
						if match = LINE.match(line)
							usage.map_count += 1
							virtual_size = parse_size(match[:virtual_size])
							resident_size = parse_size(match[:resident_size])
							dirty_size = parse_size(match[:dirty_size])
							swap_size = parse_size(match[:swap_size])
							usage.resident_size += resident_size
							usage.swap_size += swap_size
							
							# Private vs. Shared memory: COW=copy_on_write PRV=private NUL=empty ALI=aliased SHM=shared ZER=zero_filled S/A=shared_alias
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
					
					# vmmap might not fail, but also might not return any data.
					return nil if usage.map_count.zero?
					
					# Darwin does not expose proportional memory usage, so we guess based on the number of processes. Yes, this is a terrible hack, but it's the most reasonable thing to do given the constraints:
					usage.proportional_size = usage.resident_size / count
					usage.proportional_swap_size = usage.swap_size / count
					
					return usage
				end
			rescue Errno::ESRCH
				# Process doesn't exist.
				return nil
			end
		end
	end
end

# Wire Memory.capture and Memory.supported? to this implementation when vmmap is executable.
if Process::Metrics::Memory::Darwin.supported?
	class << Process::Metrics::Memory
		# Whether memory capture is supported on this platform.
		# @returns [Boolean] True if vmmap is available.
		def supported?
			true
		end
		
		# Capture memory metrics for a process.
		# @parameter pid [Integer] The process ID.
		# @parameter options [Hash] Additional options (e.g. count for proportional estimates).
		# @returns [Memory | Nil] A Memory instance with captured metrics.
		def capture(...)
			Process::Metrics::Memory::Darwin.capture(...)
		end
	end
end
