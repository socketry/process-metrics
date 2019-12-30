# frozen_string_literal: true

# Copyright, 2019, by Samuel G. D. Williams. <https://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

RSpec.describe Process::Metrics do
	it "has a version number" do
		expect(Process::Metrics::VERSION).not_to be nil
	end
	
	# This format is loosely defined by the manual page.
	describe '.duration' do
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
	
	describe '.capture' do
		subject {Process::Metrics.capture(pid: Process.pid).first}
		
		it "can get memory usage for current process" do
			is_expected.to include(
				:pid, :pcpu, :vsz, :rss, :etime
			)
		end
	end
	
	describe '.capture' do
		subject {Process::Metrics.capture(pid: Process.pid, ppid: Process.pid)}
		
		it "doesn't include ps command in own output" do
			command = subject.find{|process| process[:command].include?("ps")}
			
			expect(command).to be_nil
		end
		
		it "can get memory usage for parent process" do
			pid = Process.spawn("sleep 10")
			
			sleep 5
			
			expect(subject.size).to be >= 2
			
			command = subject.find{|process| process[:command].include?("sleep")}
			expect(command).to_not be_nil
			
			expect(command[:etime]).to be_within(1).of(5)
			
			Process.kill(:TERM, pid)
			Process.wait(pid)
		end
	end
end
