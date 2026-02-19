# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "process/metrics"

describe Process::Metrics::Host::Memory do
	with ".capture" do
		it "returns a struct with total, used, free when supported" do
			host = Process::Metrics::Host::Memory.capture
			skip "Host::Memory is not available on this platform" unless host
			expect(host).to be_a(Process::Metrics::Host::Memory)
			expect(host.total).to be_a(Integer)
			expect(host.total).to be > 0
			expect(host.used).to be_a(Integer)
			expect(host.used).to be >= 0
			expect(host.free).to be_a(Integer)
			expect(host.free).to be >= 0
			expect(host.used + host.free).to be == host.total
		end
		
		it "may include swap_total and swap_used" do
			host = Process::Metrics::Host::Memory.capture
			skip "Host::Memory is not available on this platform" unless host
			if host.swap_total
				expect(host.swap_total).to be_a(Integer)
				expect(host.swap_used).to be_a(Integer) if host.swap_used
			end
		end
		
		it "serializes to JSON" do
			host = Process::Metrics::Host::Memory.capture
			skip "Host::Memory is not available on this platform" unless host
			json = host.to_json
			parsed = JSON.parse(json)
			expect(parsed).to have_keys("total", "used", "free")
		end
	end
	
	with ".supported?" do
		it "returns true on Linux or Darwin when capture works" do
			# On CI we're either Linux or Darwin; supported? should match whether capture returns non-nil
			host = Process::Metrics::Host::Memory.capture
			expect(Process::Metrics::Host::Memory.supported?).to be == (host != nil)
		end
	end
end
