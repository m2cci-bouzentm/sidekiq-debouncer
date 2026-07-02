# ActiveJob::Debounce

Leading-edge debounce for ActiveJob. One job per debounce window, atomic Redis gating, crash recovery.

Works with **any ActiveJob backend**: Sidekiq, GoodJob, Solid Queue, Resque, etc.

**The problem:** Webhooks, callbacks, and real-time triggers fire multiple times for the same entity within seconds. Without debouncing, you get duplicate jobs flooding your queue — wasted workers, inflated stats, and race conditions.

**This gem** gates at dispatch time using Redis GETSET — only 1 job enters the queue per debounce window. Subsequent calls are true no-ops (nothing queued). Clean queue stats, full crash recovery.

## How it works

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

1. First `perform_debounce` → sets Redis key, queues job with delay
2. Subsequent calls within the window → Redis key exists, skip (nothing queued)
3. Job executes → `after_perform` cleans up Redis key
4. Next call → starts a new debounce window

## Installation

```ruby
gem 'activejob-debounce'
```

```bash
bundle install
```

## Requirements

- Ruby >= 2.7
- Rails >= 6.0 (ActiveJob, ActiveSupport)
- Redis >= 4.0

## Usage

### Basic usage

```ruby
class SyncContactJob < ApplicationJob
  include ActiveJob::Debounce::Concern

  debounce_for 30.seconds

  def perform(contact_id)
    Contact.find(contact_id).sync_to_crm
  end
end

# In your model:
class Contact < ApplicationRecord
  after_save :sync_to_crm

  private

  def sync_to_crm
    # Even if called 100 times in 30 seconds, only ONE job executes
    SyncContactJob.perform_debounce(id)
  end
end
```

### Multiple arguments

The debouncer creates unique keys based on ALL arguments:

```ruby
class UpdateTicketJob < ApplicationJob
  include ActiveJob::Debounce::Concern

  debounce_for 1.minute

  def perform(ticket_id, update_type)
    # ...
  end
end

# These are DIFFERENT debounce windows:
UpdateTicketJob.perform_debounce(123, "status")   # Window 1
UpdateTicketJob.perform_debounce(123, "priority") # Window 2
UpdateTicketJob.perform_debounce(456, "status")   # Window 3
```

### ActiveRecord objects

Pass ActiveRecord objects directly — serialized via GlobalID:

```ruby
class SyncTrainingJob < ApplicationJob
  include ActiveJob::Debounce::Concern

  debounce_for 2.minutes

  def perform(training)
    training.sync_to_external_service
  end
end

training = Training.find(123)
SyncTrainingJob.perform_debounce(training)
```

## Configuration

```ruby
# config/initializers/activejob_debounce.rb
ActiveJob::Debounce.configure do |config|
  config.default_delay = 60        # Default debounce window (seconds)
  config.buffer = 1                # Buffer to prevent race conditions (seconds)
  config.ttl = 60                  # Redis key TTL safety net (seconds)
  config.redis_connection = Redis.new(url: ENV['REDIS_URL'])  # Optional
end
```

## Crash recovery

If a job crashes without cleanup (worker killed, OOM, etc.), the Redis key holds an expired timestamp. The next `perform_debounce` call detects this and re-queues:

```
T=0s   Job queued, Redis key set to T+30
T=30s  Worker crashes — Redis key still holds T+30
T=45s  New call → GETSET returns T+30 → T+30 <= now → crash detected → re-queue
```

## How it works internally

Uses Redis `GETSET` for atomic dispatch-time gating:

1. `GETSET key new_timestamp` — atomically reads old value, writes new
2. If old value is `nil` (no job pending) or expired (crashed) → queue the job
3. If old value is in the future → job already pending, skip
4. `after_perform` deletes the key → opens the window for next cycle

This is a **leading-edge** debounce: first event triggers execution after the delay. Subsequent events during the window are dropped.

## Redis key format

```
activejob_debounce:{JobClass}:{args}
```

```ruby
SyncContactJob.debounce_key([123])
# => "activejob_debounce:SyncContactJob:123"

UpdateTicketJob.debounce_key([user, "full"])
# => "activejob_debounce:UpdateTicketJob:gid://app/User/456:full"
```

## Testing

```ruby
RSpec.describe SyncContactJob do
  let(:mock_redis) { instance_double("Redis") }

  before do
    ActiveJob::Debounce.configure { |c| c.redis_connection = mock_redis }
    allow(mock_redis).to receive(:getset, :expire, :del)
  end

  it "debounces multiple calls into one job" do
    allow(mock_redis).to receive(:getset).and_return(nil, (Time.now.to_i + 100).to_s)

    10.times { SyncContactJob.perform_debounce(123) }

    expect(enqueued_jobs.size).to eq(1)
  end
end
```

## License

MIT
