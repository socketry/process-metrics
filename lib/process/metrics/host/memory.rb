# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

module Process
	module Metrics
		# Per-host (system-wide) memory metrics. Use Host::Memory for total/used/free and swap; use Process::Metrics::Memory for per-process metrics.
		module Host
			# Struct for host memory snapshot. All sizes in bytes.
			# Stored: total_size, used_size, swap_*, reclaimable_size. free_size and available_size are derived.
			# @attribute total_size [Integer] Total memory (cgroup limit when in a container, else physical RAM).
			# @attribute used_size [Integer] Memory in use (kernel/cgroup view; on Linux includes reclaimable e.g. page cache).
			# @attribute swap_total_size [Integer, nil] Total swap, or nil if not available.
			# @attribute swap_used_size [Integer, nil] Swap in use, or nil if not available.
			# @attribute reclaimable_size [Integer, nil] Reclaimable memory (e.g. page cache, slab), or nil. Included in used_size.
			Memory = Struct.new(:total_size, :used_size, :swap_total_size, :swap_used_size, :reclaimable_size) do
				def to_h
					super.merge(free_size: free_size, available_size: available_size)
				end
				
				alias as_json to_h
				
				def to_json(*arguments)
					as_json.to_json(*arguments)
				end
				
				# Complement of used: total_size - used_size. Same meaning on all platforms.
				def free_size
					total_size - used_size
				end
				
				# Memory that could be used: free_size plus reclaimable. Use this for "available" when reclaimable_size is set; otherwise equals free_size.
				def available_size
					free_size + (reclaimable_size || 0)
				end
				
				# Create a zero-initialized Host::Memory instance.
				# @returns [Memory]
				def self.zero
					self.new(0, 0, nil, nil, nil)
				end
				
				# Whether host memory capture is supported on this platform.
				# @returns [Boolean]
				def self.supported?
					false
				end
				
				# Capture current host memory. Implemented by Host::Memory::Linux or Host::Memory::Darwin (in host/memory/linux.rb, host/memory/darwin.rb).
				# @returns [Memory | Nil] A Host::Memory instance, or nil if not supported or capture failed.
				def self.capture
					return nil
				end
			end
		end
	end
end

if RUBY_PLATFORM.include?("linux")
	require_relative "memory/linux"
elsif RUBY_PLATFORM.include?("darwin")
	require_relative "memory/darwin"
end
