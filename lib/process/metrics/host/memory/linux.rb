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
				DEFAULT_CGROUP_ROOT = "/sys/fs/cgroup"
				
				def initialize(cgroup_root: nil)
					@cgroup_root = (cgroup_root || DEFAULT_CGROUP_ROOT).to_s.chomp("/")
					@meminfo = false
				end
				
				# Capture current host memory. Reads total and used (from cgroup or meminfo), computes free, parses swap and reclaimable from meminfo/cgroup.
				# @returns [Host::Memory | Nil]
				def capture
					total = capture_total
					return nil unless total && total.positive?
					
					used = capture_used(total)
					used = 0 if used.nil? || used.negative?
					used = [used, total].min
					
					swap_total, swap_used = capture_swap
					reclaimable = capture_reclaimable
					
					return Host::Memory.new(total, used, swap_total, swap_used, reclaimable)
				end
				
				private
				
				# Path for cgroups v2 (unified): e.g. /sys/fs/cgroup/memory.stat
				def cgroup_v2_path(name)
					"#{@cgroup_root}/#{name}"
				end
				
				# Path for cgroups v1 (memory controller): e.g. /sys/fs/cgroup/memory/memory.stat
				def cgroup_v1_path(name)
					"#{@cgroup_root}/memory/#{name}"
				end
				
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
					if File.exist?(cgroup_v2_path("memory.max"))
						limit = File.read(cgroup_v2_path("memory.max")).strip
						return limit.to_i if limit != "max"
					end
					
					if File.exist?(cgroup_v1_path("memory.limit_in_bytes"))
						limit = File.read(cgroup_v1_path("memory.limit_in_bytes")).strip.to_i
						return limit if limit > 0 && limit < CGROUP_V1_UNLIMITED_THRESHOLD
					end
					
					unless meminfo_content = self.meminfo
						return nil
					end
					
					meminfo_content.each_line do |line|
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
					if File.exist?(cgroup_v2_path("memory.current"))
						current = File.read(cgroup_v2_path("memory.current")).strip.to_i
						return current
					end
					
					if File.exist?(cgroup_v1_path("memory.usage_in_bytes"))
						limit = File.read(cgroup_v1_path("memory.limit_in_bytes")).strip.to_i
						if limit > 0 && limit < CGROUP_V1_UNLIMITED_THRESHOLD
							return File.read(cgroup_v1_path("memory.usage_in_bytes")).strip.to_i
						end
					end
					
					unless meminfo_content = self.meminfo
						return nil
					end
					
					available_kilobytes = meminfo_content[/MemAvailable:\s*(\d+)\s*kB/, 1]&.to_i
					available_kilobytes ||= meminfo_content[/MemFree:\s*(\d+)\s*kB/, 1]&.to_i
					return nil unless available_kilobytes
					
					return [total - (available_kilobytes * 1024), 0].max
				end
				
				# Swap total and used in bytes from meminfo (SwapTotal, SwapFree).
				# @returns [Array(Integer, Integer)] [swap_total_bytes, swap_used_bytes], or [nil, nil] if no swap.
				def capture_swap
					return [nil, nil] unless meminfo_content = self.meminfo
					swap_total_kilobytes = meminfo_content[/SwapTotal:\s*(\d+)\s*kB/, 1]&.to_i
					swap_free_kilobytes = meminfo_content[/SwapFree:\s*(\d+)\s*kB/, 1]&.to_i
					
					return [nil, nil] unless swap_total_kilobytes
					
					swap_total_bytes = swap_total_kilobytes * 1024
					swap_used_bytes = (swap_total_kilobytes - (swap_free_kilobytes || 0)) * 1024
					
					return swap_total_bytes, swap_used_bytes
				end
				
				# Reclaimable memory in bytes (page cache, buffers, reclaimable slab). Included in used_size.
				# From cgroups v2 memory.stat "file", cgroups v1 memory.stat "cache", or meminfo Cached + Buffers + SReclaimable.
				# @returns [Integer | Nil]
				def capture_reclaimable
					if File.exist?(cgroup_v2_path("memory.stat"))
						# cgroups v2: "file" is file-backed (page cache), in bytes
						content = File.read(cgroup_v2_path("memory.stat")) rescue nil
						if content && (m = content.match(/^file\s+(\d+)/m))
							return m[1].to_i
						end
					end
					
					if File.exist?(cgroup_v1_path("memory.stat"))
						# cgroups v1: "cache" is page cache, in bytes
						content = File.read(cgroup_v1_path("memory.stat")) rescue nil
						if content && (m = content.match(/^cache\s+(\d+)/m))
							return m[1].to_i
						end
					end
					
					# meminfo: Cached + Buffers + SReclaimable (kB)
					unless meminfo_content = self.meminfo
						return nil
					end
					cached_kb = meminfo_content[/Cached:\s*(\d+)\s*kB/, 1]&.to_i || 0
					buffers_kb = meminfo_content[/Buffers:\s*(\d+)\s*kB/, 1]&.to_i || 0
					sreclaimable_kb = meminfo_content[/SReclaimable:\s*(\d+)\s*kB/, 1]&.to_i || 0
					reclaimable_kb = cached_kb + buffers_kb + sreclaimable_kb
					return reclaimable_kb * 1024
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
