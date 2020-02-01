# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'samovar'

require_relative '../general'

require 'console/terminal'

module Process
	module Metrics
		module Command
			module Bar
				BLOCK = [
					" ",
					"▏",
					"▎",
					"▍",
					"▌",
					"▋",
					"▊",
					"▉",
					"█",
				]
				
				def self.format(value, width)
					blocks = width * value
					full_blocks = blocks.floor
					partial_block = ((blocks - full_blocks) * BLOCK.size).floor
					
					if partial_block.zero?
						BLOCK.last * full_blocks
					else
						"#{BLOCK.last * full_blocks}#{BLOCK[partial_block]}"
					end.ljust(width)
				end
			end
			
			class Summary < Samovar::Command
				self.description = "Display a summary of memory usage statistics."
				
				options do
					option '--pid <integer>', "Report on a single process id.", type: Integer, required: true
					option '-p/--ppid <integer>', "Report on all children of this process id.", type: Integer, required: true
					
					option '--memory-scale <integer>', "Scale maximum memory usage to the specified amount (MiB).", type: Integer, default: 512
				end
				
				def terminal
					terminal = Console::Terminal.for($stdout)
					
					# terminal[:pid] = terminal.style(:blue)
					terminal[:command] = terminal.style(nil, nil, :bold)
					terminal[:key] = terminal.style(:cyan)
					
					terminal[:low] = terminal.style(:green)
					terminal[:medium] = terminal.style(:yellow)
					terminal[:high] = terminal.style(:red)
					
					return terminal
				end
				
				def format_pcpu(value, terminal)
					if value > 80.0
						intensity = :high
					elsif value > 50.0
						intensity = :medium
					else
						intensity = :low
					end
					
					formatted = "%5.1f%% " % value
					
					terminal.print(formatted.rjust(10), intensity, "[", Bar.format(value / 100.0, 60), "]", :reset)
				end
				
				UNITS = ["KiB", "MiB", "GiB"]
				
				def format_size(value, units: UNITS)
					unit = 0
					
					while value > 1024.0 && unit < units.size
						value /= 1024.0
						unit += 1
					end
					
					return "#{value.round(unit)}#{units[unit]}"
				end
				
				def format_memory_usage(value, terminal, scale: @options[:memory_scale])
					if value > (1024.0 * scale * 0.8)
						intensity = :high
					elsif value > (1024.0 * scale * 0.5)
						intensity = :medium
					else
						intensity = :low
					end
					
					formatted = (format_size(value) + ' ').rjust(10)
					
					terminal.print(formatted, intensity, "[", Bar.format(value / (1024.0 * scale), 60), "]", :reset)
				end
				
				def call
					terminal = self.terminal
					
					summary = Process::Metrics::General.capture(pid: @options[:pid], ppid: @options[:ppid])
					
					format_memory_usage = self.method(:format_memory_usage).curry
					memory_usage = 0
					proportional = true
					
					summary.each do |pid, general|
						terminal.print_line(:pid, pid, :reset, " ", :command, general[:command])
						
						terminal.print(:key, "Processor Usage: ".rjust(20), :reset)
						format_pcpu(general.pcpu, terminal)
						terminal.print_line
						
						if memory = general.memory
							memory_usage += memory.proportional_size
							
							terminal.print_line(
								:key, "Memory (PSS): ".rjust(20), :reset,
								format_memory_usage[memory.proportional_size]
							)
							
							terminal.print_line(
								:key, "Private (USS): ".rjust(20), :reset,
								format_memory_usage[memory.unique_size]
							)
						else
							memory_usage += general.rss
							proportional = false
							
							terminal.print_line(
								:key, "Memory (RSS): ".rjust(20), :reset,
								format_memory_usage[general.rss]
							)
						end
					end
					
					terminal.print_line("Summary")
					
					if proportional
						terminal.print_line(
							:key, "Memory (PSS): ".rjust(20), :reset,
							format_memory_usage[memory_usage]
						)
					else
						terminal.print_line(
							:key, "Memory (RSS): ".rjust(20), :reset,
							format_memory_usage[memory_usage]
						)
					end
				end
			end
		end
	end
end
