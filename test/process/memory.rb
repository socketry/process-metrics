# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require 'process/metrics'

describe Process::Metrics::Memory do
	with '.capture' do
		let(:pid) {Process.pid}
		let(:capture) {Process::Metrics::General.capture(pid: pid)}
		
		it "can get memory usage for current process" do
			unless memory = capture[pid].memory
				skip "Detailed memory information is not available on this platform!" 
			end
			
			expect(memory).to have_attributes(
				map_count: be > 0,
				total_size: be > 0,
				resident_size: be > 0,
				proportional_size: be > 0,
				shared_clean_size: be > 0,
				shared_dirty_size: be >= 0,
				private_clean_size: be >= 0,
				private_dirty_size: be >= 0,
				referenced_size: be >= 0,
				anonymous_size: be >= 0,
				swap_size: be >= 0,
				proportional_swap_size: be >= 0
			)
		end
		
		it "can generate json value" do
			unless memory = capture[pid].memory
				skip "Detailed memory information is not available on this platform!"
			end
			
			json_string = memory.to_json
			json = JSON.parse(json_string)
			
			expect(json).to have_keys(
				"map_count", "resident_size", "proportional_size", "shared_clean_size", "shared_dirty_size", "private_clean_size", "private_dirty_size", "referenced_size", "anonymous_size", "swap_size", "proportional_swap_size"
			)
		end
	end
end
