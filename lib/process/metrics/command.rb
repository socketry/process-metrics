# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "command/top"

module Process
	module Metrics
		module Command
			def self.call(*arguments)
				Top.call(*arguments)
			end
		end
	end
end
