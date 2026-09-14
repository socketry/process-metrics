# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "process/metrics/general"
require "process/metrics/host"

describe "process:metrics bake task" do
	class FakeTerminal
		attr_reader :lines
		
		def initialize
			@lines = []
			@current = +""
		end
		
		def print(*arguments)
			@current << arguments.reject{|argument| argument.is_a?(Symbol)}.join
		end
		
		def print_line(*arguments)
			print(*arguments)
			@lines << @current
			@current = +""
		end
		
		def width
			80
		end
	end
	
	let(:task) do
		mod = Module.new
		path = File.expand_path("../../../bake/process/metrics.rb", __dir__)
		mod.module_eval(File.read(path), path)
		
		terminal = self.terminal
		Class.new do
			include mod
			
			define_method(:terminal) {terminal}
			define_method(:format_memory) do |value, total|
				super(value, total, terminal)
			end
		end.new
	end
	
	let(:terminal) {FakeTerminal.new}
	
	it "does not add private memory to proportional memory in the summary total" do
		general_capture = Process::Metrics::General.method(:capture)
		host_memory_capture = Process::Metrics::Host::Memory.method(:capture)
		
		begin
			Process::Metrics::General.define_singleton_method(:capture) do |pid: nil, ppid: nil|
				memory = Process::Metrics::Memory.new(
					1,
					110 * 1024 * 1024,
					100 * 1024 * 1024,
					20 * 1024 * 1024,
					0,
					10 * 1024 * 1024,
					80 * 1024 * 1024,
					0,
					0,
					0,
					0,
					0,
					0
				)
				
				process = Process::Metrics::General.new(
					pid,
					nil,
					nil,
					0.0,
					0,
					110 * 1024 * 1024,
					0.0,
					0.0,
					0.0,
					"test process",
					memory
				)
				
				{pid => process}
			end
			
			Process::Metrics::Host::Memory.define_singleton_method(:capture) do
				Process::Metrics::Host::Memory.new(1024 * 1024 * 1024, 512 * 1024 * 1024, nil, nil, nil)
			end
			
			task.metrics(pid: 1234)
		ensure
			Process::Metrics::General.define_singleton_method(:capture, general_capture)
			Process::Metrics::Host::Memory.define_singleton_method(:capture, host_memory_capture)
		end
		
		line = terminal.lines.find{|line| line.include?("Memory (Total):")}
		
		expect(line).to be(:include?, "100.0MiB")
		expect(line).not.to be(:include?, "190.0MiB")
	end
end
