# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "process/metrics"

describe Process::Metrics::ProcessorSampler do
	def process(process_id, processor_time, start_time = 1000.0)
		Process::Metrics::General.new(process_id, nil, nil, nil, nil, nil, processor_time, nil, nil, nil, start_time)
	end
	
	def sampler(captures, timestamps)
		capture = ->(**options) do
			@capture_options = options
			captures.shift
		end
		
		clock = ->{timestamps.shift}
		
		Process::Metrics::ProcessorSampler.new(capture: capture, clock: clock)
	end
	
	with "#sample" do
		it "establishes a baseline before returning an interval sample" do
			instance = sampler([
				{1 => process(1, 1.0)},
				{1 => process(1, 2.5)},
			], [10.0, 11.0])
			
			expect(instance.sample(pid: 1)).to be(:empty?)
			sample = instance.sample(pid: 1).fetch(1)
			
			expect(@capture_options).to be == {pid: 1, memory: false}
			expect(sample.process_id).to be == 1
			expect(sample.duration).to be == 1.0
			expect(sample.processor_time).to be == 1.5
			expect(sample.processor_utilization).to be == 150.0
			expect(sample).to be(:frozen?)
		end
		
		it "reports an idle process" do
			instance = sampler([
				{1 => process(1, 1.0)},
				{1 => process(1, 1.0)},
			], [10.0, 12.0])
			
			instance.sample(pid: 1)
			sample = instance.sample(pid: 1).fetch(1)
			
			expect(sample.processor_utilization).to be == 0.0
		end
		
		it "samples multiple processes independently" do
			instance = sampler([
				{1 => process(1, 1.0), 2 => process(2, 4.0)},
				{1 => process(1, 1.5), 2 => process(2, 5.5)},
			], [10.0, 11.0])
			
			instance.sample(pid: [1, 2])
			samples = instance.sample(pid: [1, 2])
			
			expect(samples[1].processor_utilization).to be == 50.0
			expect(samples[2].processor_utilization).to be == 150.0
		end
		
		it "establishes new baselines as the process set changes" do
			instance = sampler([
				{1 => process(1, 1.0)},
				{2 => process(2, 2.0)},
				{1 => process(1, 2.0), 2 => process(2, 3.0)},
			], [10.0, 11.0, 12.0])
			
			instance.sample(pid: [1])
			expect(instance.sample(pid: [2])).to be(:empty?)
			samples = instance.sample(pid: [1, 2])
			
			expect(samples.keys).to be == [2]
		end
		
		it "does not compare different process incarnations" do
			instance = sampler([
				{1 => process(1, 1.0, 1000.0)},
				{1 => process(1, 2.0, 2000.0)},
				{1 => process(1, 3.0, 2000.0)},
			], [10.0, 11.0, 12.0])
			
			instance.sample(pid: 1)
			expect(instance.sample(pid: 1)).to be(:empty?)
			expect(instance.sample(pid: 1).fetch(1).processor_utilization).to be == 100.0
		end
		
		it "rejects non-positive durations" do
			instance = sampler([
				{1 => process(1, 1.0)},
				{1 => process(1, 2.0)},
			], [10.0, 10.0])
			
			instance.sample(pid: 1)
			expect(instance.sample(pid: 1)).to be(:empty?)
		end
		
		it "rejects decreasing processor time" do
			instance = sampler([
				{1 => process(1, 2.0)},
				{1 => process(1, 1.0)},
			], [10.0, 11.0])
			
			instance.sample(pid: 1)
			expect(instance.sample(pid: 1)).to be(:empty?)
		end
	end
end
