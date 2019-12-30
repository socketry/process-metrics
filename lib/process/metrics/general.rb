# frozen_string_literal: true

# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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
			pgid: ->(value){value.to_i},
			pcpu: ->(value){value.to_f},
			time: self.method(:duration),
			vsz: ->(value){value.to_i},
			rss: ->(value){value.to_i},
			etime: self.method(:duration),
			command: ->(value){value},
		}
		
		def self.set(ids)
			Set.new(Array(ids))
		end
		
		def self.capture(pid: nil, pgid: nil, ps: PS, fields: FIELDS)
			input, output = IO.pipe
			
			arguments = [ps]
			
			if pid && pgid.nil?
				arguments.push("-p", Array(pid).join(','))
			else
				arguments.push("ax")
			end
			
			arguments.push("-o", fields.keys.join(','))
			
			child_pid = Process.spawn(*arguments, out: output, pgroup: true)
			
			output.close
			
			header, *lines = input.readlines.map(&:strip)
			
			processes = lines.map do |line|
				fields.
					zip(line.split(/\s+/, fields.size)).
					map{|(key, type), value| [key, type.call(value)]}.
					to_h
			end
			
			if pgid
				pid = set(pid)
				pgid = set(pgid)
				
				processes.select! do |process|
					pgid.include?(process[:pgid]) || pid.include?(process[:pid])
				end
			end
			
			if Memory.supported?
				processes.each do |process|
					if pid = process[:pid]
						process[:memory] = Memory.capture(Array(process[:pid]))
					end
				end
			end
			
			return processes
		ensure
			Process.wait(child_pid) if child_pid
		end
	end
end
