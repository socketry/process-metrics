# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

def capture(pid: nil, ppid: nil)
	require "process/metrics/general"
	
	Process::Metrics::General.capture(pid: pid, ppid: ppid)
end

# Print metrics for a process or processes.
#
# @parameter pid [Integer] The process ID to capture.
# @parameter ppid [Integer] The parent process ID to capture.
def metrics(pid: nil, ppid: nil)
	require "process/metrics/general"
	require "process/metrics/host"
	
	terminal = self.terminal
	format_memory = self.method(:format_memory).curry
	
	# Host name (uname -a) as first line
	if host_name = Process::Metrics::Host.name
		terminal.print_line(host_name, :reset)
	end
	
	host = Process::Metrics::Host::Memory.capture
	terminal.print_line(
		:key, "Total Memory: ".rjust(20), :reset,
		format_size(host.total_size).rjust(9)
	)
	
	terminal.print_line(
		:key, "Used Memory: ".rjust(20), :reset,
		format_memory[host.used_size, host.total_size]
	)
	
	summary = Process::Metrics::General.capture(pid: pid, ppid: ppid)
	
	shared_memory = 0
	private_memory = 0
	total_memory = host.total_size
	
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
			format_memory[shared_memory, total_memory]
		)
	end
	
	terminal.print_line(
		:key, "Memory (Total): ".rjust(20), :reset,
		format_memory[shared_memory + private_memory, total_memory]
	)
end

protected

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

# Width in characters for progress bars (label + value + " []" ≈ 33 chars).
DEFAULT_BAR_WIDTH = 60

def bar_width(terminal, prefix_width: 33)
	if width = terminal.width
		return width - prefix_width if width > prefix_width
	end
	
	return DEFAULT_BAR_WIDTH
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
	
	terminal.print(formatted.rjust(10), intensity, "[", Bar.format(value / 100.0, bar_width(terminal)), "]", :reset)
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
	
	terminal.print(formatted, intensity, "[", Bar.format(value / total.to_f, bar_width(terminal)), "]", :reset)
end
