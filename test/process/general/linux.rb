# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "process/metrics"
# Load ProcessStatus backend so we can compare General (Linux) vs General::ProcessStatus.
require "process/metrics/general/process_status"

describe Process::Metrics::General do
	with "Linux backend matches ProcessStatus backend" do
		def assert_backends_match(linux, ps)
			expect(linux.keys.sort).to be == ps.keys.sort
			
			linux.each_key do |pid|
				linux_process = linux[pid]
				ps_process = ps[pid]
				
				expect(ps_process).not.to be_nil
				expect(linux_process.process_id).to be == ps_process.process_id
				expect(linux_process.parent_process_id).to be == ps_process.parent_process_id
				expect(linux_process.process_group_id).to be == ps_process.process_group_id
				
				# VSZ and RSS differ because ps excludes device mappings while /proc/stat includes them.
				expect(linux_process.virtual_size).to be_within(10.0).percent_of(ps_process.virtual_size)
				expect(linux_process.resident_size).to be_within(10.0).percent_of(ps_process.resident_size)
				
				expect(linux_process.command).to be == ps_process.command
				expect((linux_process.processor_time - ps_process.processor_time).abs).to be < 1.0
				expect((linux_process.elapsed_time - ps_process.elapsed_time).abs).to be < 1.0
			end
		end
		
		it "single pid capture matches" do
			skip "Linux with ps required" unless RUBY_PLATFORM.include?("linux") && Process::Metrics::General::ProcessStatus.supported?
			
			pid = Process.pid
			linux = Process::Metrics::General.capture(pid: pid, memory: false)
			ps = Process::Metrics::General::ProcessStatus.capture(pid: pid, memory: false)
			assert_backends_match(linux, ps)
		end
		
		it "pid and ppid capture matches" do
			skip "Linux with ps required" unless RUBY_PLATFORM.include?("linux") && Process::Metrics::General::ProcessStatus.supported?
			
			child_pid = Process.spawn("sleep 10")
			begin
				linux = Process::Metrics::General.capture(pid: child_pid, ppid: child_pid, memory: false)
				ps = Process::Metrics::General::ProcessStatus.capture(pid: child_pid, ppid: child_pid, memory: false)
				assert_backends_match(linux, ps)
			ensure
				Process.kill(:TERM, child_pid)
				Process.wait(child_pid)
			end
		end
	end
end
