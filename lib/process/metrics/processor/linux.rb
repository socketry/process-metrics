# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Process
	module Metrics
		class Processor
			# @private
			module Linux
				DEFAULT_CGROUP_ROOT = "/sys/fs/cgroup"
				DEFAULT_CGROUP_PATH = "/proc/self/cgroup"
				
				class << self
					# Read the effective processor quota for the current cgroup.
					# @parameter cgroup_root [String] The root of the cgroup v2 filesystem.
					# @parameter cgroup_path [String] The process cgroup membership file.
					# @returns [Float | Nil] The smallest finite quota in the cgroup hierarchy, if available.
					def quota(cgroup_root: DEFAULT_CGROUP_ROOT, cgroup_path: DEFAULT_CGROUP_PATH)
						unless relative_path = current_path(cgroup_path)
							return nil
						end
						
						root = File.expand_path(cgroup_root)
						directory = File.expand_path(relative_path.delete_prefix("/"), root)
						return nil unless directory == root || directory.start_with?("#{root}/")
						
						quota = nil
						
						loop do
							if current = read_quota(directory)
								quota = [quota, current].compact.min
							end
							
							break if directory == root
							directory = File.dirname(directory)
						end
						
						return quota
					rescue Errno::EACCES, Errno::EINVAL, Errno::ENOENT, Errno::ENOTDIR, ArgumentError
						return nil
					end
					
					private
					
					def current_path(path)
						File.foreach(path) do |line|
							hierarchy, controllers, relative_path = line.strip.split(":", 3)
							
							if hierarchy == "0" && controllers == "" && relative_path
								return relative_path
							end
						end
						
						return nil
					end
					
					def read_quota(directory)
						maximum, period = File.read(File.join(directory, "cpu.max")).split
						return nil if maximum == "max" || !maximum || !period
						
						maximum = Integer(maximum)
						period = Integer(period)
						return nil unless maximum.positive? && period.positive?
						
						return maximum.to_f / period
					rescue Errno::EACCES, Errno::EINVAL, Errno::ENOENT, Errno::ENOTDIR, ArgumentError
						return nil
					end
				end
			end
			
			# The processor capacity available to the current process.
			# This takes cgroup v2 CPU bandwidth limits into account, and otherwise returns {count} as a `Float`.
			# @returns [Float] The available processor capacity in core units.
			def self.quota
				count = self.count.to_f
				
				if quota = Linux.quota
					if quota < count
						return quota
					end
				end
				
				return count
			end
		end
	end
end
