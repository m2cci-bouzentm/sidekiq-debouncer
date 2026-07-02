# frozen_string_literal: true

require_relative "lib/activejob/debounce/version"

Gem::Specification.new do |spec|
  spec.name = "activejob-debounce"
  spec.version = ActiveJob::Debounce::VERSION
  spec.authors = ["Mohamed Bouzentm"]
  spec.email = ["bouzentoutamohamed@gmail.com"]

  spec.summary = "Leading-edge debounce for ActiveJob. One job per debounce window, atomic Redis gating, crash recovery."
  spec.description = <<~DESC
    A zero-dependency debouncing solution for ActiveJob. Uses Redis GETSET for
    atomic dispatch-time gating — only 1 job enters the queue per debounce window.
    Subsequent calls are true no-ops (nothing queued). Includes crash recovery
    via expired timestamp detection. Works with any ActiveJob backend: Sidekiq,
    GoodJob, Solid Queue, Resque, etc.
  DESC
  spec.homepage = "https://github.com/m2cci-bouzentm/activejob-debounce"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "redis", ">= 4.0"

  spec.add_development_dependency "activejob", ">= 6.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
