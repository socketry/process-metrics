# frozen_string_literal: true

# Copyright, 2019, by Samuel G. D. Williams. <https://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'memory'
require 'set'

module Process
	module Metrics
		PS = "ps"
		
		# According to the linux manual page specifications.
		def self.duration(value)
			if /((?<days>\d\d)\-)?((?<hours>\d\d):)?(?<minutes>\d\d):(?<seconds>\d\d)?/ =~ value
				(((days&.to_i || 0) * 24 + (hours&.to_i || 0)) * 60 + (minutes&.to_i || 0)) * 60 + seconds&.to_i
			end
		end
		
		# pid: Process Identifier
		# pmem: Percentage Memory used.
		# pcpu: Percentage Processor used.
		# time: The process time used (executing on CPU).
		# vsz: Virtual Size in kilobytes
		# rss: Resident Set Size in kilobytes
		# etime: The process elapsed time.
		# command: The name of the process.
		FIELDS = {
			pid: ->(value){value.to_i},
			ppid: ->(value){value.to_i},
			pgid: ->(value){value.to_i},
			pcpu: ->(value){value.to_f},
			time: self.method(:duration),
			vsz: ->(value){value.to_i},
			rss: ->(value){value.to_i},
			etime: self.method(:duration),
			command: ->(value){value},
		}
		
		class General < Struct.new(:pid, :ppid, :pgid, :pcpu, :vsz, :rss, :time, :etime, :command, :memory)
			def as_json
				{
					pid: self.pid,
					ppid: self.ppid,
					pgid: self.pgid,
					pcpu: self.pcpu,
					vsz: self.vsz,
					rss: self.rss,
					time: self.time,
					etime: self.etime,
					command: self.command,
					memory: self.memory&.as_json,
				}
			end
			
			def to_json(*arguments)
				as_json.to_json(*arguments)
			end
			
			def memory_usage
				if self.memory
					self.memory.proportional_size
				else
					self.rss
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
					if ppid = process.ppid
						hierarchy[ppid] << process.pid
					end
				end
				
				return hierarchy
			end
			
			def self.capture_memory(processes)
				processes.each do |pid, process|
					process.memory = Memory.capture(Array(pid))
				end
			end
			
			def self.capture(pid: nil, ppid: nil, ps: PS, fields: FIELDS)
				input, output = IO.pipe
				
				arguments = [ps]
				
				if pid && ppid.nil?
					arguments.push("-p", Array(pid).join(','))
				else
					arguments.push("ax")
				end
				
				arguments.push("-o", fields.keys.join(','))
				
				ps_pid = Process.spawn(*arguments, out: output, pgroup: true)
				
				output.close
				
				header, *lines = input.readlines.map(&:strip)
				
				processes = {}
				
				lines.map do |line|
					record = fields.
						zip(line.split(/\s+/, fields.size)).
						map{|(key, type), value| type.call(value)}
					
					instance = self.new(*record)
					
					processes[instance.pid] = instance
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
