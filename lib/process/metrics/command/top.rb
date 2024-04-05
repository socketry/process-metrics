# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

require 'samovar'

require_relative 'summary'
require_relative '../version'

module Process
	module Metrics
		module Command
			class Top < Samovar::Command
				self.description = "Collect memory usage statistics."
				
				options do
					option '-h/--help', "Print out help information."
					option '-v/--version', "Print out the application version."
				end
				
				nested :command, {
					'summary' => Summary,
				}, default: 'summary'
				
				def call
					if @options[:version]
						puts "#{self.name} v#{VERSION}"
					elsif @options[:help]
						self.print_usage
					else
						@command.call
					end
				end
			end
		end
	end
end
