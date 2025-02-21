# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "process/metrics"

describe Process::Metrics do
	it "has a version number" do
		expect(Process::Metrics::VERSION).to be =~ /\A\d+\.\d+\.\d+\Z/
	end
	
	# This format is loosely defined by the manual page.
	with ".duration" do
		it "can parse minutes and seconds" do
			expect(Process::Metrics.duration("00:00")).to be == 0
			expect(Process::Metrics.duration("00:01")).to be == 1
			expect(Process::Metrics.duration("01:00")).to be == 60
			expect(Process::Metrics.duration("01:01")).to be == 61
		end
		
		it "can parse hours, minutes and seconds" do
			expect(Process::Metrics.duration("00:00:00")).to be == 0
			expect(Process::Metrics.duration("00:00:01")).to be == 1
			expect(Process::Metrics.duration("01:00:00")).to be == 3600
			expect(Process::Metrics.duration("01:00:01")).to be == 3601
			expect(Process::Metrics.duration("01:01:01")).to be == 3661
		end
		
		it "can parse days, hours, minutes and seconds" do
			expect(Process::Metrics.duration("00-00:00:00")).to be == 0
			expect(Process::Metrics.duration("00-00:00:01")).to be == 1
			expect(Process::Metrics.duration("01-00:00:00")).to be == 86400
			expect(Process::Metrics.duration("01-01:01:01")).to be == (86400 + 3661)
		end
		
		it "can parse days, minutes and seconds" do
			expect(Process::Metrics.duration("00-00:00")).to be == 0
			expect(Process::Metrics.duration("00-00:01")).to be == 1
			expect(Process::Metrics.duration("01-00:00")).to be == 86400
			expect(Process::Metrics.duration("01-01:01")).to be == (86400 + 61)
		end
	end
end
