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

module Process
	module Metrics
		class Memory < Struct.new(:map_count, :total_size, :resident_size, :proportional_size, :shared_clean_size, :shared_dirty_size, :private_clean_size, :private_dirty_size, :referenced_size, :anonymous_size, :swap_size, :proportional_swap_size)
			
			alias as_json to_h
			
			def to_json(*arguments)
				as_json.to_json(*arguments)
			end
			
			# The unique set size, the size of completely private (unshared) data.
			def unique_size
				self.private_clean_size + self.private_dirty_size
			end
			
			if File.readable?('/proc/self/smaps')
				def self.supported?
					true
				end
				
				MAP = {
					"Size" => :total_size,
					"Rss" => :resident_size,
					"Pss" => :proportional_size,
					"Shared_Clean" => :shared_clean_size,
					"Shared_Dirty" => :shared_dirty_size,
					"Private_Clean" => :private_clean_size,
					"Private_Dirty" => :private_dirty_size,
					"Referenced" => :referenced_size,
					"Anonymous" => :anonymous_size,
					"Swap" => :swap_size,
					"SwapPss" => :proportional_swap_size,
				}
				
				def self.capture(pids)
					usage = self.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
					
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
									usage.map_count += 1
								end
							end
						end
					end
					
					return usage
				end
			else
				def self.supported?
					false
				end
				
				def self.capture(pids)
					return self.new
				end
			end
		end
	end
end
