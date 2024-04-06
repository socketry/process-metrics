# frozen_string_literal: true

require_relative "lib/process/metrics/version"

Gem::Specification.new do |spec|
	spec.name = "process-metrics"
	spec.version = Process::Metrics::VERSION
	
	spec.summary = "Provide detailed OS-specific process metrics."
	spec.authors = ["Samuel Williams", "Adam Daniels"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/socketry/process-metrics"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/process-metrics/",
		"funding_uri" => "https://github.com/sponsors/ioquatix",
		"source_code_uri" => "https://github.com/socketry/process-metrics.git",
	}
	
	spec.files = Dir.glob(['{bin,lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
	
	spec.executables = ["process-metrics"]
	
	spec.add_dependency "console", "~> 1.8"
	spec.add_dependency "samovar", "~> 2.1"
	spec.add_dependency "json", "~> 2"
end
