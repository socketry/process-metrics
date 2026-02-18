# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "samovar"

require_relative "../general"

require "console/terminal"

module Process
	module Metrics
		module Command
			# Helper module for rendering horizontal progress bars using Unicode block characters.
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
				
				# Format a fractional value as a horizontal bar.
				# @parameter value [Float] A value between 0.0 and 1.0 representing the fill level.
				# @parameter width [Integer] The width of the bar in characters.
				# @returns [String] A string of Unicode block characters representing the filled bar.
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
			
			# Command that displays a formatted summary of memory usage statistics for processes.
			class Summary < Samovar::Command
				self.description = "Display a summary of memory usage statistics."
				
				options do
					option "--pid <integer>", "Report on a single process id.", type: Integer
					option "-p/--ppid <integer>", "Report on all children of this process id.", type: Integer
					
					option "--total-memory <integer>", "Set the total memory relative to the usage (MiB).", type: Integer
				end
				
				# Get the configured terminal for styled output.
				# @returns [Console::Terminal] A terminal object with color/style definitions.
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
				
				# Format a processor utilization percentage with color-coded bar.
				# @parameter value [Float] The CPU utilization percentage (0.0-100.0).
				# @parameter terminal [Console::Terminal] The terminal to output styled text.
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
				
				# Format a memory size value in human-readable units.
				# @parameter value [Numeric] The size value in bytes.
				# @parameter units [Array(String)] The unit labels to use for scaling.
				# @returns [String] A formatted string with value and unit (e.g., "512KiB", "1.5MiB").
				def format_size(value, units: UNITS)
					unit = -1
					
					while value >= 1024.0 && unit < units.size - 1
						value /= 1024.0
						unit += 1
					end
					
					if unit < 0
						# Value is less than 1 KiB, show in bytes
						return "#{value.round(0)}B"
					else
						return "#{value.round(unit)}#{units[unit]}"
					end
				end
				
				# Format a memory value with a horizontal bar showing utilization relative to total.
				# @parameter value [Numeric] The memory value in bytes.
				# @parameter total [Numeric] The total memory available in bytes.
				# @parameter terminal [Console::Terminal] The terminal to output styled text.
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
				
				# Get the total memory to use for percentage calculations.
				# @returns [Integer] Total memory in bytes.
				def total_memory
					if total_memory = @options[:total_memory]
						# Convert from MiB to bytes
						return total_memory * 1024 * 1024
					else
						return Process::Metrics::Memory.total_size
					end
				end
				
				# Execute the summary command, capturing and displaying process metrics.
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
