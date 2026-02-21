# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "securerandom"
require "json"

def read_message
	if line = $stdin.gets
		return JSON.parse(line, symbolize_names: true)
	end
end

def write_message(**message)
	$stdout.puts(JSON.dump(message))
	$stdout.flush
end

begin
	write_message(action: "ready")
	
	allocations = []
	children = []
	
	while message = read_message
		case message[:action]
		when "allocate"
			allocations << SecureRandom.bytes(message[:size])
			write_message(action: "allocated", size: message[:size])
		when "free"
			allocations.pop
			write_message(action: "freed")
		when "clear"
			allocations.clear
			write_message(action: "cleared")
		when "fork"
			# Fork a child process in its own process group
			child_pid = fork do
				# Create a new process group for this child
				Process.setpgid(0, 0)
				
				# Sleep forever - will be terminated by signal
				sleep
			end
			
			children << child_pid
			write_message(action: "forked", child_pid: child_pid, children_count: children.size)
		when "stabilize"
			# Give the OS a moment to settle any page allocations
			sleep 0.1
			write_message(action: "stabilized")
		when "exit"
			break
		end
	end
rescue Interrupt
	# Ignore - normal exit.
ensure
	# Clean up any child processes using their process groups
	children.each do |child_pid|
		begin
			# Kill the process group (negative PID)
			Process.kill(:TERM, -child_pid)
			Process.wait(child_pid)
		rescue Errno::ESRCH, Errno::ECHILD
			# Child already exited
		end
	end
end
