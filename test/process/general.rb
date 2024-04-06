# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require 'process/metrics'

describe Process::Metrics::General do
	with '.capture' do
		let(:pid) {Process.pid}
		let(:capture) {Process::Metrics::General.capture(pid: pid)}
		
		it "can get memory usage for current process" do
			expect(capture).to be(:include?, pid)
		end
		
		it "can generate hash value" do
			expect(capture[pid].to_h).to have_keys(:process_id, :total_size, :virtual_size, :resident_size, :command)
		end
		
		it "can generate json value" do
			json_string = capture[pid].to_json
			json = JSON.parse(json_string)
			
			expect(json).to have_keys("process_id", "total_size", "virtual_size", "resident_size", "command")
		end
		
		it "can extract memory usage" do
			expect(capture[pid].memory_usage).to be > 0.0
		end
	end
	
	with '.capture with parent pid' do
		def before
			super
			
			@pid = Process.spawn("sleep 10")
		end
		
		def after
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
	end
end
