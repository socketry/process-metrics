# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fileutils"
require "tmpdir"
require "process/metrics"

describe Process::Metrics::Processor do
	with ".count" do
		it "returns the number of available processors" do
			count = Process::Metrics::Processor.count
			
			expect(count).to be_a(Integer)
			expect(count).to be == Etc.nprocessors
			expect(count).to be > 0
		end
	end
	
	with ".quota" do
		it "returns the available processor capacity" do
			quota = Process::Metrics::Processor.quota
			
			expect(quota).to be_a(Float)
			expect(quota).to be > 0.0
			expect(quota).to be <= Process::Metrics::Processor.count.to_f
		end
		
	end
	
	def process(process_id, processor_time, start_time = 1000.0)
		Process::Metrics::General.new(process_id, nil, nil, nil, nil, nil, processor_time, nil, start_time, nil, nil)
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

if defined?(Process::Metrics::Processor::Linux)
	describe Process::Metrics::Processor::Linux do
		def write_cgroup_path(directory, path)
			cgroup_path = File.join(directory, "cgroup")
			File.write(cgroup_path, "0::#{path}\n")
			return cgroup_path
		end
		
		def write_cpu_max(directory, value)
			FileUtils.mkdir_p(directory)
			File.write(File.join(directory, "cpu.max"), value)
		end
		
		with ".quota" do
			it "reads a fractional quota" do
				Dir.mktmpdir do |directory|
					write_cpu_max(directory, "150000 100000\n")
					cgroup_path = write_cgroup_path(directory, "/")
					
					quota = Process::Metrics::Processor::Linux.quota(cgroup_root: directory, cgroup_path: cgroup_path)
					expect(quota).to be == 1.5
				end
			end
			
			it "uses the smallest quota inherited from the cgroup hierarchy" do
				Dir.mktmpdir do |directory|
					write_cpu_max(directory, "max 100000\n")
					write_cpu_max(File.join(directory, "parent"), "100000 100000\n")
					write_cpu_max(File.join(directory, "parent", "workload"), "150000 100000\n")
					cgroup_path = write_cgroup_path(directory, "/parent/workload")
					
					quota = Process::Metrics::Processor::Linux.quota(cgroup_root: directory, cgroup_path: cgroup_path)
					expect(quota).to be == 1.0
				end
			end
			
			it "returns nil for an unlimited hierarchy" do
				Dir.mktmpdir do |directory|
					write_cpu_max(directory, "max 100000\n")
					cgroup_path = write_cgroup_path(directory, "/")
					
					quota = Process::Metrics::Processor::Linux.quota(cgroup_root: directory, cgroup_path: cgroup_path)
					expect(quota).to be == nil
				end
			end
			
			it "returns nil for invalid quota values" do
				Dir.mktmpdir do |directory|
					write_cpu_max(directory, "invalid\n")
					cgroup_path = write_cgroup_path(directory, "/")
					
					quota = Process::Metrics::Processor::Linux.quota(cgroup_root: directory, cgroup_path: cgroup_path)
					expect(quota).to be == nil
				end
			end
			
			it "returns nil when the process is not in a cgroup v2 hierarchy" do
				Dir.mktmpdir do |directory|
					cgroup_path = File.join(directory, "cgroup")
					File.write(cgroup_path, "2:cpu:/workload\n")
					
					quota = Process::Metrics::Processor::Linux.quota(cgroup_root: directory, cgroup_path: cgroup_path)
					expect(quota).to be == nil
				end
			end
			
			it "returns nil when cgroup membership cannot be read" do
				Dir.mktmpdir do |directory|
					cgroup_path = File.join(directory, "missing")
					
					quota = Process::Metrics::Processor::Linux.quota(cgroup_root: directory, cgroup_path: cgroup_path)
					expect(quota).to be == nil
				end
			end
		end
	end
end
