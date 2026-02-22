# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

module Process
	module Metrics
		module Host
			# Darwin (macOS) implementation of host memory metrics.
			# Uses sysctl (hw.memsize), vm_stat (free + inactive pages), and vm.swapusage for swap.
			class Memory::Darwin
				# Parse a size string from vm.swapusage (e.g. "1024.00M", "512.00K") into bytes.
				# @parameter size_string [String | Nil] The size string from sysctl vm.swapusage.
				# @returns [Integer | Nil] Size in bytes, or nil if size_string is nil/empty.
				def self.parse_swap_size(size_string)
					return nil unless size_string
					
					size_string = size_string.strip
					
					case size_string
					when /([\d.]+)M/i then ($1.to_f * 1024 * 1024).round
					when /([\d.]+)G/i then ($1.to_f * 1024 * 1024 * 1024).round
					when /([\d.]+)K/i then ($1.to_f * 1024).round
					else size_string.to_f.round
					end
				end
				
				# Capture current host memory. Reads total (hw.memsize), free (vm_stat), and swap (vm.swapusage).
				# @returns [Host::Memory | Nil] A Host::Memory instance, or nil if capture fails.
				def self.capture
					total = capture_total
					return nil unless total && total.positive?
					
					free = capture_free
					return nil unless free
					
					free = 0 if free.negative?
					used = [total - free, 0].max
					swap_total, swap_used = capture_swap
					
					return Host::Memory.new(total, used, swap_total, swap_used, nil)
				end
				
				# Total physical RAM in bytes, from sysctl hw.memsize.
				# @returns [Integer | Nil]
				def self.capture_total
					IO.popen(["sysctl", "-n", "hw.memsize"], "r", &:read)&.strip&.to_i
				end
				
				# Free + inactive (reclaimable) memory in bytes, from vm_stat. Matches Linux MemAvailable semantics.
				# @returns [Integer | Nil]
				def self.capture_free
					output = IO.popen(["vm_stat"], "r", &:read)
					page_size = output[/page size of (\d+) bytes/, 1]&.to_i
					return nil unless page_size && page_size.positive?
					
					pages_free = output[/Pages free:\s*(\d+)/, 1]&.to_i || 0
					pages_inactive = output[/Pages inactive:\s*(\d+)/, 1]&.to_i || 0
					return (pages_free + pages_inactive) * page_size
				end
				
				# Swap total and used in bytes, from sysctl vm.swapusage (e.g. "total = 64.00M  used = 32.00M  free = 32.00M").
				# @returns [Array(Integer | Nil, Integer | Nil)] [swap_total_bytes, swap_used_bytes], or [nil, nil] if unavailable.
				def self.capture_swap
					output = IO.popen(["sysctl", "-n", "vm.swapusage"], "r", &:read)
					return [nil, nil] unless output
					
					total_string = output[/total\s*=\s*([\d.]+\s*[KMG]?)/i, 1]
					used_string = output[/used\s*=\s*([\d.]+\s*[KMG]?)/i, 1]
					swap_total = total_string ? parse_swap_size(total_string) : nil
					swap_used = used_string ? parse_swap_size(used_string) : nil
					
					return swap_total, swap_used
				end
			end
		end
	end
end

# Wire Host::Memory to this implementation on Darwin.
class << Process::Metrics::Host::Memory
	def capture
		Process::Metrics::Host::Memory::Darwin.capture
	end
	
	def supported?
		File.exist?("/usr/bin/vm_stat")
	end
end
