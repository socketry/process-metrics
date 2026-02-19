# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

module Process
	module Metrics
		# General process information via the process status command (`ps`). Used on non-Linux platforms (e.g. Darwin)
		# where there is no /proc; ps is the portable way to get pid, ppid, times, and memory in one pass.
		module General::ProcessStatus
			PS = "ps"
			
			# The fields that will be extracted from the `ps` command (order matches -o output).
			FIELDS = {
				pid: ->(value){value.to_i},
				ppid: ->(value){value.to_i},
				pgid: ->(value){value.to_i},
				pcpu: ->(value){value.to_f},
				vsz: ->(value){value.to_i * 1024},
				rss: ->(value){value.to_i * 1024},
				time: Process::Metrics.method(:duration),
				etime: Process::Metrics.method(:duration),
				command: ->(value){value},
			}
			
			# Whether process listing via ps is available on this system.
			def self.supported?
				system("which", PS, out: File::NULL, err: File::NULL)
			end
			
			# Capture process information using ps. If given a `pid`, captures that process; if given `ppid`, captures that process and all descendants. Specify both to capture a process and its children.
			# @parameter pid [Integer | Array(Integer)] Process ID(s) to capture.
			# @parameter ppid [Integer | Array(Integer)] Parent process ID(s) to include children for.
			# @parameter memory [Boolean] Whether to capture detailed memory metrics (default: Memory.supported?).
			# @returns [Hash<Integer, General>] Map of PID to General instance.
			def self.capture(pid: nil, ppid: nil, memory: Memory.supported?)
				spawned_pid = nil
				
				header, *lines = IO.pipe do |input, output|
					arguments = [PS]
					
					# When filtering by ppid we need the full process list to build the tree, so use "ax"; otherwise limit to -p.
					if pid && ppid.nil?
						arguments.push("-p", Array(pid).join(","))
					else
						arguments.push("ax")
					end
					
					arguments.push("-o", FIELDS.keys.join(","))
					
					spawned_pid = Process.spawn(*arguments, out: output)
					output.close
					
					input.readlines.map(&:strip)
				ensure
					input.close
					
					# Always kill and reap the ps subprocess so we never leave it hanging if the pipe closes early.
					if spawned_pid
						begin
							Process.kill(:KILL, spawned_pid)
							Process.wait(spawned_pid)
						rescue => error
							warn "Failed to cleanup ps process #{spawned_pid}:\n#{error.full_message}"
						end
					end
				end
				
				processes = {}
				
				lines.each do |line|
					next if line.empty?
					
					values = line.split(/\s+/, FIELDS.size)
					next if values.size < FIELDS.size
					
					record = FIELDS.keys.map.with_index{|key, i| FIELDS[key].call(values[i])}
					instance = General.new(*record, nil)
					processes[instance.process_id] = instance
				end
				
				# Restrict to the requested pid/ppid subtree; exclude our own ps process from the result.
				if ppid
					pids = Set.new
					hierarchy = General.build_tree(processes)
					General.expand_children(Array(pid), hierarchy, pids) if pid
					General.expand_children(Array(ppid), hierarchy, pids)
					processes.select!{|process_id, _| process_id != spawned_pid && pids.include?(process_id)}
				else
					processes.delete(spawned_pid) if spawned_pid
				end
				
				General.capture_memory(processes) if memory
				
				processes
			end
		end
	end
end

# Wire General.capture to this implementation when ProcessStatus is available and the Linux backend is not active (so Linux can load both for comparison tests).
linux_supported = defined?(Process::Metrics::General::Linux) && Process::Metrics::General::Linux.supported?
if Process::Metrics::General::ProcessStatus.supported? && !linux_supported
	class << Process::Metrics::General
		def capture(...)
			Process::Metrics::General::ProcessStatus.capture(...)
		end
	end
end
