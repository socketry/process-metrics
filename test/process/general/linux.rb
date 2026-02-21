# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "process/metrics"
# Load ProcessStatus backend so we can compare General (Linux) vs General::ProcessStatus.
require "process/metrics/general/process_status"
require_relative "../../../fixtures/process/metrics/a_stable_process"

describe Process::Metrics::General do
	with "Linux backend matches ProcessStatus backend" do
		include_context Process::Metrics::AStableProcess
		
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
				# With a stable controlled process, RSS should be more consistent between measurements.
				expect(linux_process.virtual_size).to be_within(10.0).percent_of(process_status_process.virtual_size)
				expect(linux_process.resident_size).to be_within(10.0).percent_of(process_status_process.resident_size)
				
				expect(linux_process.command).to be == process_status_process.command
				expect((linux_process.processor_time - process_status_process.processor_time).abs).to be < 1.0
				expect((linux_process.elapsed_time - process_status_process.elapsed_time).abs).to be < 1.0
			end
		end
		
		it "single pid capture matches" do
			skip "Linux with ProcessStatus required" unless RUBY_PLATFORM.include?("linux") && Process::Metrics::General::ProcessStatus.supported?
			
			# Stabilize the child process before taking measurements
			@child.write_message(action: "stabilize")
			@child.wait_for_message("stabilized")
			
			linux_capture = Process::Metrics::General.capture(pid: @pid, memory: false)
			process_status_capture = Process::Metrics::General::ProcessStatus.capture(pid: @pid, memory: false)
			assert_backends_match(linux_capture, process_status_capture)
		end
		
		it "pid and ppid capture matches" do
			skip "Linux with ProcessStatus required" unless RUBY_PLATFORM.include?("linux") && Process::Metrics::General::ProcessStatus.supported?
			
			# Stabilize the child process before taking measurements
			@child.write_message(action: "stabilize")
			@child.wait_for_message("stabilized")
			
			linux_capture = Process::Metrics::General.capture(pid: @pid, ppid: @pid, memory: false)
			process_status_capture = Process::Metrics::General::ProcessStatus.capture(pid: @pid, ppid: @pid, memory: false)
			assert_backends_match(linux_capture, process_status_capture)
		end
		
		it "captures child processes by ppid" do
			skip "Linux with ProcessStatus required" unless RUBY_PLATFORM.include?("linux") && Process::Metrics::General::ProcessStatus.supported?
			
			# Fork 2 child processes
			@child.write_message(action: "fork")
			response1 = @child.wait_for_message("forked")
			
			@child.write_message(action: "fork")
			response2 = @child.wait_for_message("forked")
			
			child_pids = [response1[:child_pid], response2[:child_pid]]
			
			# Stabilize before measuring
			@child.write_message(action: "stabilize")
			@child.wait_for_message("stabilized")
			
			# Capture using ppid - should get parent + both children
			linux_capture = Process::Metrics::General.capture(ppid: @pid, memory: false)
			process_status_capture = Process::Metrics::General::ProcessStatus.capture(ppid: @pid, memory: false)
			
			# Should have captured 3 processes: parent + 2 children
			expect(linux_capture.size).to be == 3
			expect(process_status_capture.size).to be == 3
			
			# Verify parent is included
			expect(linux_capture.keys).to be(:include?, @pid)
			expect(process_status_capture.keys).to be(:include?, @pid)
			
			# Verify both children are included
			child_pids.each do |child_pid|
				expect(linux_capture.keys).to be(:include?, child_pid)
				expect(process_status_capture.keys).to be(:include?, child_pid)
				
				# Verify parent-child relationship
				expect(linux_capture[child_pid].parent_process_id).to be == @pid
				expect(process_status_capture[child_pid].parent_process_id).to be == @pid
			end
			
			# Compare all processes
			assert_backends_match(linux_capture, process_status_capture)
		end
	end
end
