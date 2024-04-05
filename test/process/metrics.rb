# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require 'process/metrics'

describe Process::Metrics do
	it "has a version number" do
		expect(Process::Metrics::VERSION).to be =~ /\A\d+\.\d+\.\d+\Z/
	end
	
	# This format is loosely defined by the manual page.
	with '.duration' do
		it 'can parse minutes and seconds' do
			expect(Process::Metrics.duration("00:00")).to be == 0
			expect(Process::Metrics.duration("00:01")).to be == 1
			expect(Process::Metrics.duration("01:00")).to be == 60
			expect(Process::Metrics.duration("01:01")).to be == 61
		end
		
		it 'can parse hours, minutes and seconds' do
			expect(Process::Metrics.duration("00:00:00")).to be == 0
			expect(Process::Metrics.duration("00:00:01")).to be == 1
			expect(Process::Metrics.duration("01:00:00")).to be == 3600
			expect(Process::Metrics.duration("01:00:01")).to be == 3601
			expect(Process::Metrics.duration("01:01:01")).to be == 3661
		end
		
		it 'can parse days, hours, minutes and seconds' do
			expect(Process::Metrics.duration("00-00:00:00")).to be == 0
			expect(Process::Metrics.duration("00-00:00:01")).to be == 1
			expect(Process::Metrics.duration("01-00:00:00")).to be == 86400
			expect(Process::Metrics.duration("01-01:01:01")).to be == (86400 + 3661)
		end
		
		it 'can parse days, minutes and seconds' do
			expect(Process::Metrics.duration("00-00:00")).to be == 0
			expect(Process::Metrics.duration("00-00:01")).to be == 1
			expect(Process::Metrics.duration("01-00:00")).to be == 86400
			expect(Process::Metrics.duration("01-01:01")).to be == (86400 + 61)
		end
	end
	
	with '.capture' do
		let(:pid) {Process.pid}
		let(:capture) {Process::Metrics::General.capture(pid: pid)}
		
		it "can get memory usage for current process" do
			expect(capture).to be(:include?, pid)
		end
		
		it "can generate hash value" do
			expect(capture[pid].to_h).to have_keys(:pid, :vsz, :rss, :command)
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
			
			expect(command[:etime]).to be >= 0.0
		end
	end
end
