# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "process/metrics"

describe Process::Metrics::Processor do
	def process(process_id, processor_time, start_time = 1000.0)
		Process::Metrics::General.new(process_id, nil, nil, nil, nil, nil, processor_time, nil, nil, nil, start_time)
	end
	
	def processor(captures, timestamps)
		capture = ->(**options) do
			@capture_options = options
			captures.shift
		end
		
		processor_class = Class.new(Process::Metrics::Processor) do
			define_method(:now) {timestamps.shift}
			private :now
		end
		
		processor_class.new(capture: capture)
	end
	
	with "#sample" do
		it "establishes a baseline before returning an interval sample" do
			instance = processor([
				{1 => process(1, 1.0)},
				{1 => process(1, 2.5)},
			], [10.0, 11.0])
			
			expect(instance.sample(1)).to be(:empty?)
			sample = instance.sample(1).fetch(1)
			
			expect(@capture_options).to be == {pid: 1, memory: false}
			expect(sample.process_id).to be == 1
			expect(sample.duration).to be == 1.0
			expect(sample.processor_time).to be == 1.5
			expect(sample.utilization).to be == 1.5
			expect(sample).to be(:frozen?)
		end
		
		it "reports an idle process" do
			instance = processor([
				{1 => process(1, 1.0)},
				{1 => process(1, 1.0)},
			], [10.0, 12.0])
			
			instance.sample(1)
			sample = instance.sample(1).fetch(1)
			
			expect(sample.utilization).to be == 0.0
		end
		
		it "samples multiple processes independently" do
			instance = processor([
				{1 => process(1, 1.0), 2 => process(2, 4.0)},
				{1 => process(1, 1.5), 2 => process(2, 5.5)},
			], [10.0, 11.0])
			
			instance.sample([1, 2])
			samples = instance.sample([1, 2])
			
			expect(samples[1].utilization).to be == 0.5
			expect(samples[2].utilization).to be == 1.5
		end
		
		it "establishes new baselines as the process set changes" do
			instance = processor([
				{1 => process(1, 1.0)},
				{2 => process(2, 2.0)},
				{1 => process(1, 2.0), 2 => process(2, 3.0)},
			], [10.0, 11.0, 12.0])
			
			instance.sample([1])
			expect(instance.sample([2])).to be(:empty?)
			samples = instance.sample([1, 2])
			
			expect(samples.keys).to be == [2]
		end
		
		it "does not compare different process incarnations" do
			instance = processor([
				{1 => process(1, 1.0, 1000.0)},
				{1 => process(1, 2.0, 2000.0)},
				{1 => process(1, 3.0, 2000.0)},
			], [10.0, 11.0, 12.0])
			
			instance.sample(1)
			expect(instance.sample(1)).to be(:empty?)
			expect(instance.sample(1).fetch(1).utilization).to be == 1.0
		end
		
		it "rejects non-positive durations" do
			instance = processor([
				{1 => process(1, 1.0)},
				{1 => process(1, 2.0)},
			], [10.0, 10.0])
			
			instance.sample(1)
			expect(instance.sample(1)).to be(:empty?)
		end
		
		it "rejects decreasing processor time" do
			instance = processor([
				{1 => process(1, 2.0)},
				{1 => process(1, 1.0)},
			], [10.0, 11.0])
			
			instance.sample(1)
			expect(instance.sample(1)).to be(:empty?)
		end
	end
end
