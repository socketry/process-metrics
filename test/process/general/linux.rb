# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "process/metrics"
# Load ProcessStatus backend so we can compare General (Linux) vs General::ProcessStatus.
require "process/metrics/general/process_status"

describe Process::Metrics::General do
	with "Linux backend matches ProcessStatus backend" do
		def assert_backends_match(linux_capture, process_status_capture)
			expect(linux_capture.keys.sort).to be == process_status_capture.keys.sort
			
			linux_capture.each_key do |pid|
				linux_process = linux_capture[pid]
				process_status_process = process_status_capture[pid]
				
				expect(process_status_process).not.to be_nil
				expect(linux_process.process_id).to be == process_status_process.process_id
				expect(linux_process.parent_process_id).to be == process_status_process.parent_process_id
				expect(linux_process.process_group_id).to be == process_status_process.process_group_id
				
				# VSZ and RSS differ because ps excludes device mappings while /proc/stat includes them.
				expect(linux_process.virtual_size).to be_within(10.0).percent_of(process_status_process.virtual_size)
				expect(linux_process.resident_size).to be_within(10.0).percent_of(process_status_process.resident_size)
				
				expect(linux_process.command).to be == process_status_process.command
				expect((linux_process.processor_time - process_status_process.processor_time).abs).to be < 1.0
				expect((linux_process.elapsed_time - process_status_process.elapsed_time).abs).to be < 1.0
			end
		end
		
		it "single pid capture matches" do
			skip "Linux with ProcessStatus required" unless RUBY_PLATFORM.include?("linux") && Process::Metrics::General::ProcessStatus.supported?
			
			pid = Process.pid
			linux_capture = Process::Metrics::General.capture(pid: pid, memory: false)
			process_status_capture = Process::Metrics::General::ProcessStatus.capture(pid: pid, memory: false)
			assert_backends_match(linux_capture, process_status_capture)
		end
		
		it "pid and ppid capture matches" do
			skip "Linux with ProcessStatus required" unless RUBY_PLATFORM.include?("linux") && Process::Metrics::General::ProcessStatus.supported?
			
			child_pid = Process.spawn("sleep 10")
			begin
				linux_capture = Process::Metrics::General.capture(pid: child_pid, ppid: child_pid, memory: false)
				process_status_capture = Process::Metrics::General::ProcessStatus.capture(pid: child_pid, ppid: child_pid, memory: false)
				assert_backends_match(linux_capture, process_status_capture)
			ensure
				Process.kill(:TERM, child_pid)
				Process.wait(child_pid)
			end
		end
	end
end
