require_relative 'lib/process/metrics/version'

Gem::Specification.new do |spec|
	spec.name = "process-metrics"
	spec.version = Process::Metrics::VERSION
	spec.authors = ["Samuel Williams"]
	spec.email = ["samuel.williams@oriontransfer.co.nz"]
	
	spec.summary = "Provide detailed OS-specific process metrics."
	spec.homepage = "https://github.com/socketry/process-metrics"
	spec.license = "MIT"
	
	spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")
	
	spec.metadata["funding_uri"] = "https://github.com/sponsors/ioquatix"
	
	# Specify which files should be added to the gem when it is released.
	# The `git ls-files -z` loads the files in the RubyGem that have been added into git.
	spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
		`git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
	end
	
	spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.require_paths = ["lib"]
	
	spec.add_dependency "console", "~> 1.8"
	spec.add_dependency "samovar", "~> 2.1"
	
	spec.add_development_dependency "covered"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "rake", "~> 12.0"
	spec.add_development_dependency "rspec", "~> 3.8"
end
