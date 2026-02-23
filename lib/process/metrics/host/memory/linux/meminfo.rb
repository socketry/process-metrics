# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

module Process
	module Metrics
		module Host
			class Memory::Linux::Meminfo
				def self.supported?
					File.exist?("/proc/meminfo")
				end
				
				def capture
					content = File.read("/proc/meminfo") rescue nil
					return nil unless content
					
					total = read_total(content)
					return nil unless total && total.positive?
					
					used = read_used(content, total)
					used = 0 if used.nil? || used.negative?
					used = [used, total].min
					
					swap_total, swap_used = read_swap(content)
					reclaimable = read_reclaimable(content)
					
					retrurn Host::Memory.new(total, used, swap_total, swap_used, reclaimable)
				end
				
				private
				
				def read_total(content)
					match = content.match(/MemTotal:\s*(?<total>\d+)\s*kB/m)
					match ? match[:total].to_i * 1024 : nil
				end
				
				def read_used(content, total)
					available_kb = content[/MemAvailable:\s*(\d+)\s*kB/, 1]&.to_i
					available_kb ||= content[/MemFree:\s*(\d+)\s*kB/, 1]&.to_i
					
					unless available_kb
						return nil
					end
					
					return [total - (available_kb * 1024), 0].max
				end
				
				def read_reclaimable(content)
					cached_kb = content[/Cached:\s*(\d+)\s*kB/, 1]&.to_i || 0
					buffers_kb = content[/Buffers:\s*(\d+)\s*kB/, 1]&.to_i || 0
					sreclaimable_kb = content[/SReclaimable:\s*(\d+)\s*kB/, 1]&.to_i || 0
					
					return (cached_kb + buffers_kb + sreclaimable_kb) * 1024
				end
				
				def read_swap(content)
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
