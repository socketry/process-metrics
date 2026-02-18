# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "json"

module Process
	module Metrics
		# Represents memory usage for a process, sizes are in bytes.
		class Memory < Struct.new(:map_count, :resident_size, :proportional_size, :shared_clean_size, :shared_dirty_size, :private_clean_size, :private_dirty_size, :referenced_size, :anonymous_size, :swap_size, :proportional_swap_size, :minor_faults, :major_faults)
			
			alias as_json to_h
			
			# Convert the object to a JSON string.
			def to_json(*arguments)
				as_json.to_json(*arguments)
			end
			
			# The total size of the process in memory.
			def total_size
				self.resident_size + self.swap_size
			end
			
			# The unique set size, the size of completely private (unshared) data.
			def unique_size
				self.private_clean_size + self.private_dirty_size
			end
			
			# Create a zero-initialized Memory instance.
			# @returns [Memory] A new Memory object with all fields set to zero.
			def self.zero
				self.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			end
			
			# Whether the memory usage can be captured on this system.
			def self.supported?
				false
			end
			
			# Capture memory usage for the given process IDs.
			def self.capture(pid, **options)
				return nil
			end
		end
	end
end

require_relative "memory/linux"
require_relative "memory/darwin"
