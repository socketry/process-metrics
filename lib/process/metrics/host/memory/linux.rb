# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

module Process
	module Metrics
		module Host
			# Linux implementation of host memory metrics.
			# Uses cgroups v2 (memory.max, memory.current) or cgroups v1 (memory.limit_in_bytes, memory.usage_in_bytes) when in a container;
			# otherwise reads /proc/meminfo (MemTotal, MemAvailable/MemFree, SwapTotal/SwapFree). Parses meminfo once per capture and reuses it.
			class Memory::Linux
				# Threshold for distinguishing actual memory limits from "unlimited" sentinel values in cgroups v1.
				# In cgroups v1, when memory.limit_in_bytes is set to unlimited (by writing -1), the kernel stores a very large sentinel near 2^63.
				# Any value >= 2^60 (1 exabyte) is treated as unlimited and we fall back to /proc/meminfo.
				# Reference: https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt
				CGROUP_V1_UNLIMITED_THRESHOLD = 2**60
				
				def initialize
					@meminfo = false
				end
				
				# Capture current host memory. Reads total and used (from cgroup or meminfo), computes free, and parses swap from meminfo.
				# @returns [Host::Memory | Nil]
				def capture
					total = capture_total
					return nil unless total && total.positive?
					
					used = capture_used(total)
					used = 0 if used.nil? || used.negative?
					used = [used, total].min
					free = total - used
					
					swap_total, swap_used = capture_swap
					
					return Host::Memory.new(total, used, free, swap_total, swap_used)
				end
				
				private
				
				# Memoized /proc/meminfo contents. Used for total (MemTotal), used (via MemAvailable), and swap when not in a cgroup.
				# @returns [String | Nil]
				def meminfo
					if @meminfo == false
						@meminfo = File.read("/proc/meminfo") rescue nil
					end
					
					return @meminfo
				end
				
				# Total memory in bytes: cgroups v2 memory.max, cgroups v1 memory.limit_in_bytes (if < threshold), else MemTotal from meminfo.
				# @returns [Integer | Nil]
				def capture_total
					if File.exist?("/sys/fs/cgroup/memory.max")
						limit = File.read("/sys/fs/cgroup/memory.max").strip
						return limit.to_i if limit != "max"
					end
					
					if File.exist?("/sys/fs/cgroup/memory/memory.limit_in_bytes")
						limit = File.read("/sys/fs/cgroup/memory/memory.limit_in_bytes").strip.to_i
						return limit if limit > 0 && limit < CGROUP_V1_UNLIMITED_THRESHOLD
					end
					
					unless meminfo = self.meminfo
						return nil 
					end
					
					meminfo.each_line do |line|
						if /MemTotal:\s*(?<total>\d+)\s*kB/ =~ line
							return $~[:total].to_i * 1024
						end
					end
					
					return nil
				end
				
				# Current memory usage in bytes: cgroups v2 memory.current, cgroups v1 memory.usage_in_bytes, or total - MemAvailable from meminfo.
				# @parameter total [Integer] Total memory (used to compute used from MemAvailable when not in cgroup).
				# @returns [Integer | Nil]
				def capture_used(total)
					if File.exist?("/sys/fs/cgroup/memory.current")
						current = File.read("/sys/fs/cgroup/memory.current").strip.to_i
						return current
					end
					
					if File.exist?("/sys/fs/cgroup/memory/memory.usage_in_bytes")
						limit = File.read("/sys/fs/cgroup/memory/memory.limit_in_bytes").strip.to_i
						if limit > 0 && limit < CGROUP_V1_UNLIMITED_THRESHOLD
							return File.read("/sys/fs/cgroup/memory/memory.usage_in_bytes").strip.to_i
						end
					end
					
					unless meminfo = self.meminfo
						return nil 
					end
					
					available_kb = meminfo[/MemAvailable:\s*(\d+)\s*kB/, 1]&.to_i
					available_kb ||= meminfo[/MemFree:\s*(\d+)\s*kB/, 1]&.to_i
					return nil unless available_kb
					
					return [total - (available_kb * 1024), 0].max
				end
				
				# Swap total and used in bytes from meminfo (SwapTotal, SwapFree).
				# @returns [Array(Integer, Integer)] [swap_total_bytes, swap_used_bytes], or [nil, nil] if no swap.
				def capture_swap
					return [nil, nil] unless meminfo
					swap_total_kb = meminfo[/SwapTotal:\s*(\d+)\s*kB/, 1]&.to_i
					swap_free_kb = meminfo[/SwapFree:\s*(\d+)\s*kB/, 1]&.to_i
					
					return [nil, nil] unless swap_total_kb
					
					swap_total_bytes = swap_total_kb * 1024
					swap_used_bytes = (swap_total_kb - (swap_free_kb || 0)) * 1024
					
					return swap_total_bytes, swap_used_bytes
				end
			end
		end
	end
end

# Wire Host::Memory to this implementation on Linux.
class << Process::Metrics::Host::Memory
	def capture
		Process::Metrics::Host::Memory::Linux.new.capture
	end
	
	def supported?
		File.exist?("/proc/meminfo")
	end
end
