# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "etc"

module Process
	module Metrics
		# General process information by reading /proc. Used on Linux to avoid spawning `ps`.
		# We read directly from the kernel (proc(5)) so there is no subprocess and no parsing of
		# external command output; same data source as the kernel uses for process accounting.
		# Parses /proc/[pid]/stat and /proc/[pid]/cmdline for each process.
		module General::Linux
			# Clock ticks per second for /proc stat times (utime, stime, starttime).
			CLK_TCK = Etc.sysconf(Etc::SC_CLK_TCK) rescue 100
			
			# Page size in bytes for RSS (resident set size is in pages in /proc/pid/stat).
			PAGE_SIZE = Etc.sysconf(Etc::SC_PAGESIZE) rescue 4096
			
			# Whether /proc is available so we can list processes without ps.
			def self.supported?
				File.directory?("/proc") && File.readable?("/proc/self/stat")
			end
			
			# Capture process information from /proc. If given `pid`, captures only those process(es). If given `ppid`, captures that parent and all descendants. Both can be given to capture a process and its children.
			# @parameter pid [Integer | Array(Integer)] Process ID(s) to capture.
			# @parameter ppid [Integer | Array(Integer)] Parent process ID(s) to include children for.
			# @parameter memory [Boolean] Whether to capture detailed memory metrics (default: Memory.supported?).
			# @returns [Hash<Integer, General>] Map of PID to General instance.
			def self.capture(pid: nil, ppid: nil, memory: Memory.supported?)
				# When filtering by ppid we need the full process list to build the parent-child tree,
				# so we enumerate all numeric /proc entries; when only pid is set we read just those.
				pids_to_read = if pid && ppid.nil?
					Array(pid)
				else
					Dir.children("/proc").filter{|e| e.match?(/\A\d+\z/)}.map(&:to_i)
				end
				
				uptime_jiffies = nil
				
				processes = {}
				pids_to_read.each do |pid|
					stat_path = "/proc/#{pid}/stat"
					next unless File.readable?(stat_path)
					
					stat_content = File.read(stat_path)
					# comm field can contain spaces and parentheses; find the closing ')' (proc(5)).
					closing_paren_index = stat_content.rindex(")")
					next unless closing_paren_index
					
					executable_name = stat_content[1...closing_paren_index]
					fields = stat_content[(closing_paren_index + 2)..].split(/\s+/)
					# After comm: state(3), ppid(4), pgrp(5), ... utime(14), stime(15), ... starttime(22), vsz(23), rss(24). 0-based: ppid=1, pgrp=2, utime=11, stime=12, starttime=19, vsz=20, rss=21.
					parent_process_id = fields[1].to_i
					process_group_id = fields[2].to_i
					utime = fields[11].to_i
					stime = fields[12].to_i
					starttime = fields[19].to_i
					virtual_size = fields[20].to_i
					resident_pages = fields[21].to_i
					
					# Read /proc/uptime once per capture and reuse for every process (starttime is in jiffies since boot).
					uptime_jiffies ||= begin
						uptime_seconds = File.read("/proc/uptime").split(/\s+/).first.to_f
						(uptime_seconds * CLK_TCK).to_i
					end
					
					processor_time = (utime + stime).to_f / CLK_TCK
					elapsed_time = [(uptime_jiffies - starttime).to_f / CLK_TCK, 0.0].max
					
					command = read_command(pid, executable_name)
					
					processes[pid] = General.new(
						pid,
						parent_process_id,
						process_group_id,
						0.0, # processor_utilization: would need two samples; not available from single stat read
						virtual_size,
						resident_pages * PAGE_SIZE,
						processor_time,
						elapsed_time,
						command,
						nil
					)
				rescue Errno::ENOENT, Errno::ESRCH, Errno::EACCES
					# Process disappeared or we can't read it.
					next
				end
				
				# Restrict to the requested pid/ppid subtree using the same tree logic as the ps backend.
				if ppid
					pids = Set.new
					hierarchy = General.build_tree(processes)
					General.expand_children(Array(pid), hierarchy, pids) if pid
					General.expand_children(Array(ppid), hierarchy, pids)
					processes.select!{|process_id, _| pids.include?(process_id)}
				end
				
				General.capture_memory(processes) if memory
				
				processes
			end
			
			# Read command line from /proc/[pid]/cmdline; fall back to executable name from stat if empty.
			# Use binread because cmdline is NUL-separated and may contain non-UTF-8 bytes; we split on NUL and join for display.
			def self.read_command(pid, command_fallback)
				path = "/proc/#{pid}/cmdline"
				return command_fallback unless File.readable?(path)
				
				cmdline_content = File.binread(path)
				return command_fallback if cmdline_content.empty?
				
				# cmdline is NUL-separated; replace with spaces for display.
				cmdline_content.split("\0").join(" ").strip
			rescue Errno::ENOENT, Errno::ESRCH, Errno::EACCES
				command_fallback
			end
		end
	end
end

if Process::Metrics::General::Linux.supported?
	class << Process::Metrics::General
		def capture(...)
			Process::Metrics::General::Linux.capture(...)
		end
	end
else
	require_relative "process_status"
end
