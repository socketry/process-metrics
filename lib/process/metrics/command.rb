# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "command/top"

module Process
	module Metrics
		# @namespace
		module Command
			# Call the default command (Top).
			# @parameter arguments [Array] Command-line arguments to pass through.
			def self.call(*arguments)
				Top.call(*arguments)
			end
		end
	end
end
