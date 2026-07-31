# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Process
	module Metrics
		module Host
			# Captures host memory limits and usage from a cgroup v2 filesystem.
			class Memory::Linux::CgroupV2
				DEFAULT_CGROUP_ROOT = "/sys/fs/cgroup"
				
				# Whether cgroup v2 memory metrics are available.
				# @parameter cgroup_root [String | Nil] The root of the cgroup filesystem.
				# @returns [Boolean] Whether the required cgroup v2 files exist.
				def self.supported?(cgroup_root = DEFAULT_CGROUP_ROOT)
					root = (cgroup_root || DEFAULT_CGROUP_ROOT).to_s.chomp("/")
					
					if File.exist?("#{root}/memory.current") && File.exist?("#{root}/memory.max")
						return true
					end
					
					return false
				end
				
				# Initialize the cgroup v2 memory reader.
				# @parameter cgroup_root [String | Nil] The root of the cgroup filesystem.
				def initialize(cgroup_root: nil)
					@cgroup_root = (cgroup_root || DEFAULT_CGROUP_ROOT).to_s.chomp("/")
				end
				
				# Capture host memory from the cgroup v2 filesystem.
				# @returns [Host::Memory | Nil] The captured host memory, if the cgroup has a finite limit.
				def capture
					total = read_total
					return nil unless total && total.positive?
					
					used = read_used
					used = 0 if used.nil? || used.negative?
					used = [used, total].min
					
					swap_total, swap_used = read_swap
					reclaimable = read_reclaimable
					
					return Host::Memory.new(total, used, swap_total, swap_used, reclaimable)
				end
				
				private
				
				def path(name)
					"#{@cgroup_root}/#{name}"
				end
				
				def read_total
					limit = File.read(path("memory.max")).strip
					
					if limit == "max"
						return nil
					end
					
					return limit.to_i
				end
				
				def read_used
					File.read(path("memory.current")).strip.to_i
				end
				
				def read_reclaimable
					unless content = (File.read(path("memory.stat")) rescue nil)
						return nil
					end
					
					match = content.match(/^file\s+(\d+)/m)
					return match ? match[1].to_i : nil
				end
				
				def read_swap
					unless content = (File.read("/proc/meminfo") rescue nil)
						return [nil, nil]
					end
					
					swap_total_kb = content[/SwapTotal:\s*(\d+)\s*kB/, 1]&.to_i
					swap_free_kb = content[/SwapFree:\s*(\d+)\s*kB/, 1]&.to_i
					
					unless swap_total_kb
						return [nil, nil]
					end
					
					swap_total = swap_total_kb * 1024
					swap_used = (swap_total_kb - (swap_free_kb || 0)) * 1024
					return swap_total, swap_used
				end
			end
		end
	end
end
