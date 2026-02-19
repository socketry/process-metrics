# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "process/metrics"

describe Process::Metrics::General do
	with ".capture" do
		let(:pid) {Process.pid}
		let(:capture) {Process::Metrics::General.capture(pid: pid)}
		
		it "can get memory usage for current process" do
			expect(capture).to be(:include?, pid)
		end
		
		it "can generate hash value" do
			expect(capture[pid].to_h).to have_keys(:process_id, :virtual_size, :resident_size, :command)
		end
		
		it "can generate json value" do
			json_string = capture[pid].to_json
			json = JSON.parse(json_string)
			
			expect(json).to have_keys("process_id", "total_size", "virtual_size", "resident_size", "command")
		end
		
		it "can extract memory usage" do
			expect(capture[pid].memory_usage).to be > 0.0
		end

		it "sets parent_process_id and process_group_id" do
			process = capture[pid]
			expect(process.process_id).to be == pid
			expect(process.parent_process_id).to be_a(Integer)
			expect(process.process_group_id).to be_a(Integer)
		end
	end

	with ".capture with ppid only" do
		def before
			super
			@child_pid = Process.spawn("sleep 10")
		end

		def after(error = nil)
			super
			Process.kill(:TERM, @child_pid) if @child_pid
			Process.wait(@child_pid) if @child_pid
		end

		let(:capture) { Process::Metrics::General.capture(ppid: Process.pid) }

		it "includes descendants of the given ppid" do
			expect(capture).to be(:include?, @child_pid)
			child = capture[@child_pid]
			expect(child).not.to be_nil
			expect(child.command).to be(:include?, "sleep")
			expect(child.parent_process_id).to be == Process.pid
		end
	end

	with ".capture with parent pid" do
		def before
			super
			
			@pid = Process.spawn("sleep 10")
		end
		
		def after(error = nil)
			super
			
			Process.kill(:TERM, @pid)
			Process.wait(@pid)
		end
		
		let(:capture) {Process::Metrics::General.capture(pid: @pid, ppid: @pid)}
		
		it "doesn't include ps command in own output" do
			command = capture.each_value.find{|process| process.command.include?("ps")}
			
			expect(command).to be_nil
		end
		
		it "can get memory usage for parent process" do
			expect(capture.size).to be >= 1
			
			command = capture.each_value.find{|process| process.command.include?("sleep")}
			expect(command).not.to be_nil
			
			expect(command[:elapsed_time]).to be >= 0.0
			expect(command[:processor_time]).to be >= 0.0
			expect(command[:processor_utilization]).to be >= 0.0
		end

		it "sets parent_process_id and process_group_id on child" do
			child = capture[@pid]
			expect(child).not.to be_nil
			expect(child.parent_process_id).to be_a(Integer)
			expect(child.process_group_id).to be_a(Integer)
		end
	end
end
