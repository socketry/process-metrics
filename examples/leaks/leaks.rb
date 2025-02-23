#!/usr/bin/env ruby

require "process/metrics"
require "async/clock"
require "securerandom"

class RingBuffer
	def initialize(size)
		@size = 0
		
		@buffer = Array.new(size)
		@index = 0
	end
	
	attr :size
	
	def full?
		@size == @buffer.size
	end
	
	def <<(value)
		index = (@index + @size) % @buffer.size
		@buffer[index] = value
		
		if @size < @buffer.size
			@size += 1
		end
	end
	
	def each
		return enum_for(:each) unless block_given?
		
		@size.times do |i|
			index = (@index + i) % @buffer.size
			yield @buffer[index]
		end
	end
	
	include Enumerable
end

class LeakDetector
	class Sample < Struct.new(:time, :memory)
		def self.capture
			new(Async::Clock.now, Process::Metrics::Memory.capture(Process.pid).proportional_size)
		end
		
		def delta(sample)
			(memory - sample.memory) / (time - sample.time)
		end
	end
	
	def initialize(threshold: 0.0, interval: 10.0, samples: 12)
		@threshold = threshold
		@interval = interval
		
		@derivatives = RingBuffer.new(samples)
		@previous_sample = nil
	end
	
	def run
		@thread = Thread.new do
			loop do
				capture_sample
				check_for_leaks!
				sleep @interval
			end
		end
	end
	
	private
	
	def capture_sample
		sample = Sample.capture
		
		$stderr.puts "Sample: #{sample.memory.round(2)} KB"
		
		if @previous_sample
			@derivatives << sample.delta(@previous_sample)
		end
		
		@previous_sample = sample
	end
	
	def check_for_leaks!
		return unless samples.full?
		
		average_derivative = @derivatives.sum / @derivatives.size
		
		if average_derivative > @threshold
			$stderr.puts "🚨 Memory leak detected!"
			puts "Average derivative: #{average_derivative.round(2)} KB/s"
			puts "Cumulative derivative: #{@cumulative_derivative.round(2)} KB"
			puts "Derivatives: #{@derivatives.map { |d| d.round(2) }.join(', ')}"
		end
	end
end

# Initialize and run the leak detector
leak_detector = LeakDetector.new
leak_detector.run

leak_rate = 1024 * 1024 # 1 MB/s

loop do
	leaks = Array.new(10) do
		SecureRandom.random_bytes(leak_rate)
		sleep 0.1
	end
end
