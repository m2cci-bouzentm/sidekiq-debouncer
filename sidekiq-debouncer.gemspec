# frozen_string_literal: true

require_relative "lib/sidekiq/debouncer/version"

Gem::Specification.new do |spec|
  spec.name = "sidekiq-debouncer"
  spec.version = Sidekiq::Debouncer::VERSION
  spec.authors = ["Mohamed Bouzentm"]
  spec.email = ["bouzentoutamohamed@gmail.com"]

  spec.summary = "Debounce Sidekiq/ActiveJob jobs to prevent redundant API calls and rate limiting"
  spec.description = <<~DESC
    A simple, zero-dependency debouncing solution for Sidekiq and ActiveJob.
    Prevents redundant job execution by coalescing multiple calls within a
    configurable time window into a single job execution. Perfect for avoiding
    rate limits on external APIs like HubSpot, Stripe, Salesforce, etc.
  DESC
  spec.homepage = "https://github.com/m2cci-bouzentm/sidekiq-debouncer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies - only what's truly required
  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "redis", ">= 4.0"

  # Development dependencies
  spec.add_development_dependency "activejob", ">= 6.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
end
