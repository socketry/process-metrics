# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "json"

module Process
	module Metrics
		class StableChild
			def initialize
				@io = IO.popen(["ruby", File.expand_path("stable_child.rb", __dir__)], "r+")
				@children = []
			end
			
			def process_id
				@io.pid
			end
			
			def children
				@children.dup
			end
			
			def close
				if io = @io
					@io = nil
					io.close
				end
			end
			
			def write_message(**message)
				@io.puts(JSON.dump(message))
			end
			
			def read_message
				if line = @io.gets
					return JSON.parse(line, symbolize_names: true)
				end
			end
			
			def wait_for_message(action)
				while message = read_message
					if message[:action] == action
						# Track forked children
						if action == "forked" && message[:child_pid]
							@children << message[:child_pid]
						end
						
						return message
					end
				end
			end
		end
		
		AStableProcess = Sus::Shared("a stable process") do
			around do |&block|
				begin
					@child = StableChild.new
					@pid = @child.process_id
					
					# Wait for child to be ready
					@child.wait_for_message("ready")
					
					super(&block)
				ensure
					@child&.close
					@child = nil
					@pid = nil
				end
			end
		end
	end
end
