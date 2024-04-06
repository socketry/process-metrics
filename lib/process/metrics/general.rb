# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require_relative 'memory'
require 'set'
require 'json'

module Process
	module Metrics
		PS = "ps"
		
		# Parse a duration string into seconds.
		# According to the linux manual page specifications.
		def self.duration(value)
			if /((?<days>\d\d)\-)?((?<hours>\d\d):)?(?<minutes>\d\d):(?<seconds>\d\d)?/ =~ value
				(((days&.to_i || 0) * 24 + (hours&.to_i || 0)) * 60 + (minutes&.to_i || 0)) * 60 + seconds&.to_i
			end
		end
		
		# The fields that will be extracted from the `ps` command.
		FIELDS = {
			pid: ->(value){value.to_i}, # Process ID
			ppid: ->(value){value.to_i}, # Parent Process ID
			pgid: ->(value){value.to_i}, # Process Group ID
			pcpu: ->(value){value.to_f}, # Percentage CPU
			time: self.method(:duration), # CPU Time
			sz: ->(value){value.to_i}, # Total Size
			vsz: ->(value){value.to_i}, #	Virtual Size
			rss: ->(value){value.to_i}, # Resident Size
			etime: self.method(:duration), # Elapsed Time
			command: ->(value){value}, # Command (name of the process)
		}
		
		# General process information.
		class General < Struct.new(:process_id, :parent_process_id, :process_group_id, :processor_utilization, :total_size, :virtual_size, :resident_size, :processor_time, :elapsed_time, :command, :memory)
			# Convert the object to a JSON serializable hash.
			def as_json
				{
					process_id: self.process_id,
					parent_process_id: self.parent_process_id,
					process_group_id: self.process_group_id,
					processor_utilization: self.processor_utilization,
					total_size: self.total_size,
					virtual_size: self.virtual_size,
					resident_size: self.resident_size,
					processor_time: self.processor_time,
					elapsed_time: self.elapsed_time,
					command: self.command,
					memory: self.memory&.as_json,
				}
			end
			
			# Convert the object to a JSON string.
			def to_json(*arguments)
				as_json.to_json(*arguments)
			end
		
			# The general memory usage of the process using the best available information.
			def memory_usage
				if memory = self.memory
					memory.proportional_size
				else
					self.total_size
				end
			end
			
			def self.expand_children(children, hierarchy, pids)
				children.each do |pid|
					self.expand(pid, hierarchy, pids)
				end
			end
			
			def self.expand(pid, hierarchy, pids)
				unless pids.include?(pid)
					pids << pid
					
					if children = hierarchy.fetch(pid, nil)
						self.expand_children(children, hierarchy, pids)
					end
				end
			end
			
			def self.build_tree(processes)
				hierarchy = Hash.new{|h,k| h[k] = []}
				
				processes.each_value do |process|
					if parent_process_id = process.parent_process_id
						hierarchy[parent_process_id] << process.process_id
					end
				end
				
				return hierarchy
			end
			
			def self.capture_memory(processes)
				processes.each do |pid, process|
					process.memory = Memory.capture(Array(pid))
				end
			end
			
			# Capture process information. If given a `pid`, it will capture the details of that process. If given a `ppid`, it will capture the details of all child processes. Specify both `pid` and `ppid` if you want to capture a process and all its children.
			#
			# @parameter pid [Integer] The process ID to capture.
			# @parameter ppid [Integer] The parent process ID to capture.
			def self.capture(pid: nil, ppid: nil, ps: PS)
				input, output = IO.pipe
				
				arguments = [ps]
				
				if pid && ppid.nil?
					arguments.push("-p", Array(pid).join(','))
				else
					arguments.push("ax")
				end
				
				arguments.push("-o", FIELDS.keys.join(','))
				
				ps_pid = Process.spawn(*arguments, out: output, pgroup: true)
				
				output.close
				
				header, *lines = input.readlines.map(&:strip)
				
				processes = {}
				
				lines.map do |line|
					record = FIELDS.
						zip(line.split(/\s+/, FIELDS.size)).
						map{|(key, type), value| type.call(value)}
					
					instance = self.new(*record)
					
					processes[instance.process_id] = instance
				end
				
				if ppid
					pids = Set.new
					
					hierarchy = self.build_tree(processes)
					
					self.expand_children(Array(pid), hierarchy, pids)
					self.expand_children(Array(ppid), hierarchy, pids)
					
					processes.select! do |pid, process|
						if pid != ps_pid
							pids.include?(pid)
						end
					end
				end
				
				if Memory.supported?
					self.capture_memory(processes)
					
					# if pid
					# 	self.compute_summary(pid, processes)
					# end
				end
				
				return processes
			ensure
				Process.wait(ps_pid) if ps_pid
			end
		end
	end
end
