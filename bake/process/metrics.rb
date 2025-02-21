
def capture(pid: nil, ppid: nil)
	require "process/metrics/general"
	
	Process::Metrics::General.capture(pid: pid, ppid: ppid)
end

