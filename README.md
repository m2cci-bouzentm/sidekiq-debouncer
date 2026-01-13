# Sidekiq::Debouncer

A simple, lightweight debouncing solution for Sidekiq and ActiveJob. Prevents redundant job execution by coalescing multiple calls within a configurable time window into a single job execution.

**Perfect for:**
- Avoiding rate limits on external APIs (HubSpot, Stripe, Salesforce, etc.)
- Batching rapid updates into a single operation
- Preventing redundant background work when data changes frequently

## How It Works

```
Time: 0s     5s      10s     30s     35s
      |      |       |       |       |
      v      v       v       v       v
    call   call    call   [executes] call
      |______|_______|          |_____|
           |                        |
    These 3 calls become       This call
    ONE execution              starts new window
```

When you call `perform_debounce`:
1. If no job is pending for these arguments, schedule one
2. If a job is already pending, ignore the call (the pending job will handle it)
3. After the job executes, the Redis key is cleaned up
4. Future calls start a new debounce window

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq-debouncer'
```

Then execute:

```bash
$ bundle install
```

## Requirements

- Ruby >= 2.7
- Rails >= 6.0 (ActiveJob, ActiveSupport)
- Redis >= 4.0
- Sidekiq (any version that works with your Rails version)

## Usage

### Basic Usage

Include the concern in your job and set the debounce duration:

```ruby
class SyncContactToHubspotJob < ApplicationJob
  include Sidekiq::Debouncer::Concern

  debounce_for 30.seconds

  def perform(contact_id)
    contact = Contact.find(contact_id)
    HubspotClient.sync(contact)
  end
end

# In your model or controller:
class Contact < ApplicationRecord
  after_save :sync_to_hubspot

  private

  def sync_to_hubspot
    # Even if called 100 times in 30 seconds,
    # only ONE job will execute
    SyncContactToHubspotJob.perform_debounce(id)
  end
end
```

### With Multiple Arguments

The debouncer creates unique keys based on ALL arguments:

```ruby
class UpdateTicketJob < ApplicationJob
  include Sidekiq::Debouncer::Concern

  debounce_for 1.minute

  def perform(ticket_id, update_type)
    # ...
  end
end

# These are treated as DIFFERENT debounce windows:
UpdateTicketJob.perform_debounce(123, "status")   # Window 1
UpdateTicketJob.perform_debounce(123, "priority") # Window 2
UpdateTicketJob.perform_debounce(456, "status")   # Window 3
```

### With ActiveRecord Objects

You can pass ActiveRecord objects directly. They're serialized using GlobalID:

```ruby
class SyncTrainingJob < ApplicationJob
  include Sidekiq::Debouncer::Concern

  debounce_for 2.minutes

  def perform(training)
    training.sync_to_external_service
  end
end

# Both of these refer to the same debounce window:
training = Training.find(123)
SyncTrainingJob.perform_debounce(training)
SyncTrainingJob.perform_debounce(Training.find(123))
```

## Configuration

Configure global defaults in an initializer:

```ruby
# config/initializers/sidekiq_debouncer.rb
Sidekiq::Debouncer.configure do |config|
  # Default debounce delay if not specified per-job (default: 60 seconds)
  config.default_delay = 60

  # Buffer time to prevent race conditions (default: 1 second)
  config.buffer = 1

  # TTL for Redis keys as a safety net (default: 60 seconds)
  config.ttl = 60

  # Custom Redis connection (optional, defaults to Redis.current)
  config.redis_connection = Redis.new(url: ENV['REDIS_URL'])
end
```

## How It Prevents Rate Limits

Consider syncing contacts to HubSpot with a rate limit of 100 requests/10 seconds:

**Without debouncing:**
```ruby
# User updates 50 contacts rapidly
50.times { |i| Contact.find(i).update(name: "New Name #{i}") }
# => 50 API calls in milliseconds = potential rate limit hit
```

**With debouncing:**
```ruby
# Same 50 updates, but with debouncing
# => Only 50 jobs scheduled for 30 seconds later
# => If more updates happen in that window, still just 50 jobs
# => API calls are spread out over time
```

## Testing

In your tests, you can verify debouncing behavior:

```ruby
RSpec.describe SyncContactToHubspotJob do
  before do
    # Use test adapter to inspect enqueued jobs
    ActiveJob::Base.queue_adapter = :test
  end

  it "debounces multiple calls into one job" do
    10.times { SyncContactToHubspotJob.perform_debounce(123) }

    expect(enqueued_jobs.size).to eq(1)
  end

  it "creates separate jobs for different arguments" do
    5.times { SyncContactToHubspotJob.perform_debounce(123) }
    5.times { SyncContactToHubspotJob.perform_debounce(456) }

    expect(enqueued_jobs.size).to eq(2)
  end
end
```

## Redis Key Format

Keys follow the pattern: `sidekiq_debouncer:{JobClass}:{args}`

```ruby
UpdateTicketJob.debounce_key([123])
# => "sidekiq_debouncer:UpdateTicketJob:123"

SyncJob.debounce_key([user, "full"])
# => "sidekiq_debouncer:SyncJob:gid://app/User/456:full"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

```bash
git clone https://github.com/yourusername/sidekiq-debouncer.git
cd sidekiq-debouncer
bundle install
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/sidekiq-debouncer.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
