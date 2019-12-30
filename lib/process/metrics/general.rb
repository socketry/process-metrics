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

module Process
	module Metrics
		PS = "ps"
		
		# pid: Process Identifier
		# pmem: Percentage Memory used.
		# pcpu: Percentage Processor used.
		# time: The process time used (executing on CPU).
		# vsz: Virtual Size in kilobytes
		# rss: Resident Set Size in kilobytes
		# etime: The process elapsed time.
		# command: The name of the process.
		COLUMNS = [:pid, :pmem, :pcpu, :time, :vsz, :rss, :etime, :command]
		
		def self.pidlist(pid)
			Array(pid).join(",")
		end
		
		def self.capture(pid: nil, ppid: nil, ps: PS, columns: COLUMNS)
			input, output = IO.pipe
			
			arguments = [ps, "-o", columns.join(',')]
			
			if pid
				arguments.append("--pid", pidlist(pid))
			end
			
			if ppid
				arguments.append("--ppid", pidlist(ppid))
			end
			
			system(*arguments, out: output, pgroup: true)
			
			output.close
			
			header, *lines = input.readlines.map(&:strip)
			
			# keys = header.split(/\s+/).map(&:downcase)
			keys = columns
			
			processes = lines.map do |line|
				keys.zip(line.split(/\s+/, keys.size)).to_h
			end
			
			if Memory.supported?
				processes.each do |process|
					if pid = process[:pid]
						process[:memory] = Memory.capture(Array(process[:pid]))
					end
				end
			end
			
			return processes
		end
	end
end
