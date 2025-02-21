# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "samovar"

require_relative "../general"

require "console/terminal"

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
					option "--pid <integer>", "Report on a single process id.", type: Integer, required: true
					option "-p/--ppid <integer>", "Report on all children of this process id.", type: Integer, required: true
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
				
				def format_processor_utilization(value, terminal)
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
				
				def format_memory_usage(value, total, terminal)
					if value > (total * 0.8)
						intensity = :high
					elsif value > (total * 0.5)
						intensity = :medium
					else
						intensity = :low
					end
					
					formatted = (format_size(value) + " ").rjust(10)
					
					terminal.print(formatted, intensity, "[", Bar.format(value / total.to_f, 60), "]", :reset)
				end
				
				def call
					terminal = self.terminal
					
					summary = Process::Metrics::General.capture(pid: @options[:pid], ppid: @options[:ppid])
					
					format_memory_usage = self.method(:format_memory_usage).curry
					shared_memory_usage = 0
					private_memory_usage = 0
					total_memory_usage = Process::Metrics::Memory.total_size
					
					proportional = true
					
					summary.each do |pid, general|
						terminal.print_line(:pid, pid, :reset, " ", :command, general[:command])
						
						terminal.print(:key, "Processor Usage: ".rjust(20), :reset)
						format_processor_utilization(general.processor_utilization, terminal)
						terminal.print_line
						
						if memory = general.memory
							shared_memory_usage += memory.proportional_size
							private_memory_usage += memory.unique_size
							
							terminal.print_line(
								:key, "Shared Memory: ".rjust(20), :reset,
								format_memory_usage[memory.proportional_size, total_memory_usage]
							)
							
							terminal.print_line(
								:key, "Private Memory: ".rjust(20), :reset,
								format_memory_usage[memory.unique_size, total_memory_usage]
							)
						else
							shared_memory_usage += general.resident_size
							proportional = false
							
							terminal.print_line(
								:key, "Memory: ".rjust(20), :reset,
								format_memory_usage[general.resident_size, total_memory_usage]
							)
						end
					end
					
					terminal.print_line("Summary")
					
					if proportional
						terminal.print_line(
							:key, "Shared Memory: ".rjust(20), :reset,
							format_memory_usage[shared_memory_usage, total_memory_usage]
						)
						
						terminal.print_line(
							:key, "Private Memory: ".rjust(20), :reset,
							format_memory_usage[private_memory_usage, total_memory_usage]
						)
					else
						terminal.print_line(
							:key, "Memory: ".rjust(20), :reset,
							format_memory_usage[memory_usage, total_memory_usage]
						)
					end
					
					terminal.print_line(
						:key, "Memory (Total): ".rjust(20), :reset,
						format_memory_usage[shared_memory_usage + private_memory_usage, total_memory_usage]
					)
				end
			end
		end
	end
end
