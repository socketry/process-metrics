# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

# A small demo to visualize COW-related minor page fault trends.
# - Allocates page-sized strings in an array.
# - Forks a child that mutates one byte of a different string each second.
# - Parent samples Process::Metrics and prints minor/major fault deltas and unique memory growth.

require "process/metrics"

PAGE_SIZE = Integer(ENV.fetch("PAGE_SIZE", "4096")) # bytes
PAGES     = Integer(ENV.fetch("PAGES", "128"))      # number of page-sized strings
DURATION  = Integer(ENV.fetch("DURATION", "30"))    # seconds to run/monitor

# Allocate an array of page-sized mutable strings:
array = Array.new(PAGES){"\x00" * PAGE_SIZE}

child_pid = fork do
	$0 = "cow-child"
	i = 0
	start = Time.now
	while (Time.now - start) < DURATION
		idx = i % PAGES
		s = array[idx]
		# Mutate a single byte; this should trigger a COW on the underlying page on first write:
		s.setbyte(0, (s.getbyte(0) + 1) & 0xFF)
		i += 1
		sleep 1
	end
end

puts "Monitoring child PID=#{child_pid} for #{DURATION}s (PAGE_SIZE=#{PAGE_SIZE}, PAGES=#{PAGES})"

last_minor = nil
last_major = nil
last_unique = nil

DURATION.times do |t|
	procs = Process::Metrics::General.capture(pid: child_pid)
	proc = procs[child_pid]
	unless proc
		puts "[%2ds] child process is no longer listed" % t
		break
	end
	mem = proc.memory
	unless mem
		puts "[%2ds] detailed memory metrics not available on this platform" % t
		break
	end
	
	minor = mem.minor_faults.to_i
	major = mem.major_faults.to_i
	unique = mem.unique_size.to_i          # bytes
	
	delta_minor = last_minor ? (minor - last_minor) : 0
	delta_major = last_major ? (major - last_major) : 0
	delta_unique = last_unique ? (unique - last_unique) : 0
	
	puts "[%2ds] minor: %d (+%d), major: %d (+%d), unique_bytes: %d (+%d)" % [t, minor, delta_minor, major, delta_major, unique, delta_unique]
	
	last_minor = minor
	last_major = major
	last_unique = unique
	
	sleep 1
end

begin
	Process.kill(:TERM, child_pid)
rescue Errno::ESRCH
	# already exited
end

begin
	_, status = Process.wait2(child_pid)
	if status
		if status.signaled?
			puts "Child terminated by signal #{status.termsig}"
		else
			puts "Child exited with status #{status.exitstatus}"
		end
	end
rescue Errno::ECHILD
	# already reaped
end
