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

module Process
	module Metrics
		module Memory
			if File.readable?('/proc/self/smaps')
				def self.supported?
					true
				end
				
				MAP = {
					"Size" => :total,
					"Rss" => :rss,
					"Pss" => :pss,
					"Shared_Clean" => :shared_clean,
					"Shared_Dirty" => :shared_dirty,
					"Private_Clean" => :private_clean,
					"Private_Dirty" => :private_dirty,
					"Referenced" => :referenced,
					"Anonymous" => :anonymous,
					"Swap" => :swap,
					"SwapPss" => :swap_pss,
				}
				
				def self.capture(pids)
					usage = Hash.new{|h,k| h[k] = 0}
					
					pids.each do |pid|
						if lines = File.readlines("/proc/#{pid}/smaps")
							lines.each do |line|
								# The format of this is fixed according to:
								# https://github.com/torvalds/linux/blob/351c8a09b00b5c51c8f58b016fffe51f87e2d820/fs/proc/task_mmu.c#L804-L814
								if /(?<name>.*?):\s+(?<value>\d+) kB/ =~ line
									if key = MAP[name]
										usage[key] += value.to_i
									end
								elsif /VmFlags:\s+(?<flags>.*)/ =~ line
									# It should be possible to extract the number of fibers and each fiber's memory usage.
									# flags = flags.split(/\s+/)
									usage[:maps] += 1
								end
							end
						end
					end
					
					return usage.freeze
				end
			else
				def self.supported?
					false
				end
				
				def self.capture(pids)
				end
			end
		end
	end
end
