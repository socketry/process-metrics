# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require_relative "host/memory"

module Process
	module Metrics
		module Host
			# System name from uname -a (kernel name, nodename, release, etc.). Returns nil if uname is not available.
			# @returns [String, nil]
			def self.name
				IO.popen(["uname", "-a"], "r", &:read)&.strip
			rescue Errno::ENOENT
				nil
			end
		end
	end
end
