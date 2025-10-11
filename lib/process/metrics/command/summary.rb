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
					option "--pid <integer>", "Report on a single process id.", type: Integer
					option "-p/--ppid <integer>", "Report on all children of this process id.", type: Integer
					
					option "--total-memory <integer>", "Set the total memory relative to the usage (MiB).", type: Integer
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
				
				def format_memory(value, total, terminal)
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
				
				def total_memory
					if total_memory = @options[:total_memory]
						return total_memory * 1024
					else
						return Process::Metrics::Memory.total_size
					end
				end
				
				def call
					# Validate required arguments: at least one of --pid or --ppid must be provided:
					unless @options[:pid] || @options[:ppid]
						raise Samovar::MissingValueError.new(self, "pid or ppid")
					end
					
					terminal = self.terminal
					
					summary = Process::Metrics::General.capture(pid: @options[:pid], ppid: @options[:ppid])
					
					format_memory = self.method(:format_memory).curry
					shared_memory = 0
					private_memory = 0
					total_memory = self.total_memory
					
					proportional = true
					
					summary.each do |pid, general|
						terminal.print_line(:pid, pid, :reset, " ", :command, general[:command])
						
						terminal.print(:key, "Processor Usage: ".rjust(20), :reset)
						format_processor_utilization(general.processor_utilization, terminal)
						terminal.print_line
						
						if memory = general.memory
							shared_memory += memory.proportional_size
							private_memory += memory.unique_size
							
							terminal.print_line(
								:key, "Memory: ".rjust(20), :reset,
								format_memory[memory.proportional_size, total_memory]
							)
							
							terminal.print_line(
								:key, "Private Memory: ".rjust(20), :reset,
								format_memory[memory.unique_size, total_memory]
							)
						else
							shared_memory += general.resident_size
							proportional = false
							
							terminal.print_line(
								:key, "Memory: ".rjust(20), :reset,
								format_memory[general.resident_size, total_memory]
							)
						end
					end
					
					terminal.print_line("Summary")
					
					if proportional
						terminal.print_line(
							:key, "Memory: ".rjust(20), :reset,
							format_memory[shared_memory, total_memory]
						)
						
						terminal.print_line(
							:key, "Private Memory: ".rjust(20), :reset,
							format_memory[private_memory, total_memory]
						)
					else
						terminal.print_line(
							:key, "Memory: ".rjust(20), :reset,
							format_memory[memory, total_memory]
						)
					end
					
					terminal.print_line(
						:key, "Memory (Total): ".rjust(20), :reset,
						format_memory[shared_memory + private_memory, total_memory]
					)
				end
			end
		end
	end
end
