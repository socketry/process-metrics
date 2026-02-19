# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

module Process
	module Metrics
		# Per-host (system-wide) memory metrics. Use Host::Memory for total/used/free and swap; use Process::Metrics::Memory for per-process metrics.
		module Host
			# Struct for host memory snapshot. All sizes in bytes.
			# @attribute total_size [Integer] Total memory (cgroup limit when in a container, else physical RAM).
			# @attribute used_size [Integer] Memory in use (total_size - free_size).
			# @attribute free_size [Integer] Available memory (MemAvailable-style: free + reclaimable).
			# @attribute swap_total_size [Integer, nil] Total swap, or nil if not available.
			# @attribute swap_used_size [Integer, nil] Swap in use, or nil if not available.
			Memory = Struct.new(:total_size, :used_size, :free_size, :swap_total_size, :swap_used_size) do
				alias as_json to_h
				
				def to_json(*arguments)
					as_json.to_json(*arguments)
				end
				
				# Create a zero-initialized Host::Memory instance.
				# @returns [Memory]
				def self.zero
					self.new(0, 0, 0, nil, nil)
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
