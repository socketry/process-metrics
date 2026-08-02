# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "process/metrics/general/process_status"

describe Process::Metrics::General::ProcessStatus do
	it "normalizes processor utilization to core units" do
		values = ["125.0"]
		
		expect(subject::FIELDS[:pcpu].call(values)).to be == 1.25
	end
end
