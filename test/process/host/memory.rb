# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "tmpdir"
require "process/metrics"

describe Process::Metrics::Host::Memory do
	with ".capture" do
		it "returns a struct with total_size, used_size, free_size when supported" do
			host = Process::Metrics::Host::Memory.capture
			skip "Host::Memory is not available on this platform" unless host
			expect(host).to be_a(Process::Metrics::Host::Memory)
			expect(host.total_size).to be_a(Integer)
			expect(host.total_size).to be > 0
			expect(host.used_size).to be_a(Integer)
			expect(host.used_size).to be >= 0
			expect(host.free_size).to be_a(Integer)
			expect(host.free_size).to be >= 0
			expect(host.used_size + host.free_size).to be == host.total_size
		end
		
		it "may include swap_total_size and swap_used_size" do
			host = Process::Metrics::Host::Memory.capture
			skip "Host::Memory is not available on this platform" unless host
			if host.swap_total_size
				expect(host.swap_total_size).to be_a(Integer)
				expect(host.swap_used_size).to be_a(Integer) if host.swap_used_size
			end
		end
		
		it "may include reclaimable_size (Linux: page cache etc., included in used_size)" do
			host = Process::Metrics::Host::Memory.capture
			skip "Host::Memory is not available on this platform" unless host
			if host.reclaimable_size != nil
				expect(host.reclaimable_size).to be_a(Integer)
				expect(host.reclaimable_size).to be >= 0
				expect(host.reclaimable_size).to be <= host.used_size
			end
		end
		
		it "serializes to JSON" do
			host = Process::Metrics::Host::Memory.capture
			skip "Host::Memory is not available on this platform" unless host
			json = host.to_json
			parsed = JSON.parse(json)
			expect(parsed).to have_keys("total_size", "used_size", "free_size", "available_size", "reclaimable_size")
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

if defined?(Process::Metrics::Host::Memory::Linux)
	describe Process::Metrics::Host::Memory::Linux do
		with "fake cgroup_root" do
			it "reads total_size, used_size, reclaimable_size from fake cgroup v2 files" do
				skip "Only runs on Linux" unless RUBY_PLATFORM.include?("linux")
				Dir.mktmpdir do |dir|
					total_bytes = 1_073_741_824
					used_bytes = 800_000_000
					file_reclaimable_bytes = 123_456_789
					File.write(File.join(dir, "memory.max"), total_bytes.to_s)
					File.write(File.join(dir, "memory.current"), used_bytes.to_s)
					File.write(File.join(dir, "memory.stat"), "anon 0\nfile #{file_reclaimable_bytes}\nkernel 0\n")
					host = Process::Metrics::Host::Memory::Linux.new(cgroup_root: dir).capture
					expect(host).to be_a(Process::Metrics::Host::Memory)
					expect(host.total_size).to be == total_bytes
					expect(host.used_size).to be == used_bytes
					expect(host.free_size).to be == total_bytes - used_bytes
					expect(host.reclaimable_size).to be == file_reclaimable_bytes
				end
			end
		end
	end
end
