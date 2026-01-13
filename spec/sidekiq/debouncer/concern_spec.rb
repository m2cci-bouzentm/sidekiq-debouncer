# frozen_string_literal: true

require "spec_helper"

# Test job class
class TestDebouncedJob < ActiveJob::Base
  include Sidekiq::Debouncer::Concern

  DEBOUNCE_DURATION = 2
  debounce_for DEBOUNCE_DURATION

  cattr_accessor :execution_count, default: 0

  def perform(*_args)
    self.class.execution_count += 1
  end
end

# Another test job with different duration
class AnotherDebouncedJob < ActiveJob::Base
  include Sidekiq::Debouncer::Concern

  debounce_for 10

  def perform(*_args); end
end

RSpec.describe Sidekiq::Debouncer::Concern do
  let(:mock_redis) { instance_double("Redis") }

  before do
    Sidekiq::Debouncer.configure do |config|
      config.redis_connection = mock_redis
    end
    TestDebouncedJob.execution_count = 0
    allow(mock_redis).to receive(:expire)
    allow(mock_redis).to receive(:del)
  end

  describe ".debounce_for" do
    it "sets the debounce duration" do
      expect(TestDebouncedJob.debounce_settings[:duration]).to eq(2)
    end

    it "can be set differently for each job class" do
      expect(AnotherDebouncedJob.debounce_settings[:duration]).to eq(10)
    end
  end

  describe ".debounce_key" do
    it "generates a key with job class and arguments" do
      key = TestDebouncedJob.debounce_key([123])
      expect(key).to eq("sidekiq_debouncer:TestDebouncedJob:123")
    end

    it "handles multiple arguments" do
      key = TestDebouncedJob.debounce_key([123, "foo", "bar"])
      expect(key).to eq("sidekiq_debouncer:TestDebouncedJob:123:foo:bar")
    end

    it "handles array arguments" do
      key = TestDebouncedJob.debounce_key([123, %w[a b]])
      expect(key).to include("sidekiq_debouncer:TestDebouncedJob:")
    end

    it "generates different keys for different arguments" do
      key1 = TestDebouncedJob.debounce_key([123, "a"])
      key2 = TestDebouncedJob.debounce_key([123, "b"])
      key3 = TestDebouncedJob.debounce_key([456, "a"])

      expect(key1).not_to eq(key2)
      expect(key1).not_to eq(key3)
      expect(key2).not_to eq(key3)
    end
  end

  describe ".perform_debounce" do
    context "when no job is pending (first call)" do
      before do
        allow(mock_redis).to receive(:getset).and_return(nil)
      end

      it "queues a job" do
        expect {
          TestDebouncedJob.perform_debounce(123)
        }.to have_enqueued_job(TestDebouncedJob).with(123)
      end

      it "sets the Redis key with expiry" do
        expect(mock_redis).to receive(:expire)
        TestDebouncedJob.perform_debounce(123)
      end
    end

    context "when a job is already pending (subsequent calls)" do
      before do
        # Return a timestamp in the future (job pending)
        allow(mock_redis).to receive(:getset).and_return((Time.now.to_i + 100).to_s)
      end

      it "does not queue another job" do
        expect {
          TestDebouncedJob.perform_debounce(123)
        }.not_to have_enqueued_job(TestDebouncedJob)
      end
    end

    context "when timestamp has expired (job finished or crashed)" do
      before do
        # Return a timestamp in the past
        allow(mock_redis).to receive(:getset).and_return((Time.now.to_i - 100).to_s)
      end

      it "queues a new job" do
        expect {
          TestDebouncedJob.perform_debounce(123)
        }.to have_enqueued_job(TestDebouncedJob).with(123)
      end
    end

    it "queues only one job for multiple calls with same arguments" do
      allow(mock_redis).to receive(:getset).and_return(nil, (Time.now.to_i + 100).to_s)

      10.times { TestDebouncedJob.perform_debounce(123) }

      enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == TestDebouncedJob }
      expect(enqueued.size).to eq(1)
    end

    it "queues separate jobs for different arguments" do
      call_count = 0
      allow(mock_redis).to receive(:getset) do
        call_count += 1
        call_count.odd? ? nil : (Time.now.to_i + 100).to_s
      end

      5.times { TestDebouncedJob.perform_debounce(123) }
      5.times { TestDebouncedJob.perform_debounce(456) }

      enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == TestDebouncedJob }
      expect(enqueued.size).to eq(2)
    end
  end

  describe "after_perform callback" do
    it "cleans up the Redis key after job execution" do
      allow(mock_redis).to receive(:getset).and_return(nil)

      TestDebouncedJob.perform_debounce(999)

      expect(mock_redis).to receive(:del).with("sidekiq_debouncer:TestDebouncedJob:999")

      # Manually trigger perform to test callback
      job = TestDebouncedJob.new(999)
      job.perform_now
    end
  end
end
