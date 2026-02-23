# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "json"
require_relative "host"

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
			
			# The private set size, the size of completely private (unshared) data.
			# This is the sum of Private_Clean and Private_Dirty pages.
			# @returns [Integer] Total private memory in bytes.
			def private_size
				self.private_clean_size + self.private_dirty_size
			end
			
			# The private set size is also known as the unique set size.
			alias unique_size private_size
			
			# The total size of shared (potentially shared with other processes) memory.
			# This is the sum of Shared_Clean and Shared_Dirty pages.
			#
			# When tracking Copy-on-Write (CoW) activity in forked processes:
			# - Initially, most memory is shared between parent and child.
			# - As the child writes to memory, CoW triggers and shared pages become private.
			# - Tracking shared_size decrease vs unique_size increase can indicate CoW activity.
			# - If shared_size decreases by X and unique_size increases by ~X, it's likely CoW.
			#
			# @returns [Integer] Total shared memory in bytes.
			def shared_size
				self.shared_clean_size + self.shared_dirty_size
			end
			
			# Create a zero-initialized Memory instance.
			# @returns [Memory] A new Memory object with all fields set to zero.
			def self.zero
				self.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			end
			
			# Total system/host memory in bytes. Delegates to Host::Memory.capture.
			# @returns [Integer | Nil]
			def self.total_size
				Host::Memory.capture&.total_size
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

if RUBY_PLATFORM.include?("linux")
	require_relative "memory/linux"
elsif RUBY_PLATFORM.include?("darwin")
	require_relative "memory/darwin"
end
