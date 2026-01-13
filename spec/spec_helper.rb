# frozen_string_literal: true

require "bundler/setup"
require "sidekiq-debouncer"
require "active_job"
require "globalid"

# Configure ActiveJob for testing
ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Logger.new(nil)

# Mock GlobalID for testing
GlobalID.app = "test-app"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    # Reset configuration between tests
    Sidekiq::Debouncer.reset_configuration!

    # Clear enqueued jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear if ActiveJob::Base.queue_adapter.respond_to?(:enqueued_jobs)
  end
end
