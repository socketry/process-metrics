# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

def capture(pid: nil, ppid: nil)
	require "process/metrics/general"
	
	Process::Metrics::General.capture(pid: pid, ppid: ppid)
end

