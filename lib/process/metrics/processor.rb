# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Process
	module Metrics
		# Computes interval CPU utilization from cumulative process metrics.
		class Processor
			# An immutable measurement of process CPU usage over an interval.
			# @attribute [Integer] The process ID.
			# @attribute [Float] The elapsed monotonic time in seconds.
			# @attribute [Float] The CPU time consumed during the interval in seconds.
			# @attribute [Float] The CPU utilization in core units, where `1.0` represents one fully occupied core. Multi-threaded processes may report values greater than `1.0`.
			class Sample < Struct.new(:process_id, :duration, :processor_time, :utilization)
			end
			
			# @private
			Snapshot = Struct.new(:start_time, :processor_time, :timestamp)
			
			# Initialize a process metrics sampler.
			# @parameter capture [Interface(:call)] The process snapshot capture callable.
			def initialize(capture: General.method(:capture))
				@capture = capture
				@snapshots = {}
			end
			
			# Sample CPU utilization for the given processes.
			# The first observation of each process establishes a baseline and does not produce a sample.
			# @parameter process_ids [Integer | Array(Integer)] The process IDs to sample.
			# @returns [Hash(Integer, Processor::Sample)] The valid interval samples keyed by process ID.
			def sample(process_ids)
				processes = @capture.call(pid: process_ids, memory: false)
				timestamp = now
				return {} unless finite?(timestamp)
				
				samples = {}
				snapshots = {}
				
				processes.each do |process_id, process|
					start_time = process.start_time
					processor_time = process.processor_time
					next unless finite?(start_time) && finite?(processor_time)
					
					current = Snapshot.new(start_time, processor_time, timestamp)
					snapshots[process_id] = current
					
					if previous = @snapshots[process_id]
						next unless previous.start_time == current.start_time
						
						duration = current.timestamp - previous.timestamp
						processor_time = current.processor_time - previous.processor_time
						next unless finite?(duration) && duration > 0.0
						next unless finite?(processor_time) && processor_time >= 0.0
						
						utilization = processor_time / duration
						next unless finite?(utilization)
						
						samples[process_id] = Sample.new(process_id, duration, processor_time, utilization).freeze
					end
				end
				
				@snapshots = snapshots
				
				return samples
			end
			
			private
			
			# Get the current monotonic time.
			def now
				Process.clock_gettime(Process::CLOCK_MONOTONIC)
			end
			
			# Whether the value is a finite number.
			def finite?(value)
				value.is_a?(Numeric) && value.finite?
			end
		end
	end
end
