# frozen_string_literal: true

RSpec.describe Sidekiq::Debouncer do
  it "has a version number" do
    expect(Sidekiq::Debouncer::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "allows setting default_delay" do
      described_class.configure do |config|
        config.default_delay = 120
      end

      expect(described_class.configuration.default_delay).to eq(120)
    end

    it "allows setting buffer" do
      described_class.configure do |config|
        config.buffer = 5
      end

      expect(described_class.configuration.buffer).to eq(5)
    end

    it "allows setting ttl" do
      described_class.configure do |config|
        config.ttl = 300
      end

      expect(described_class.configuration.ttl).to eq(300)
    end

    it "allows setting custom redis connection" do
      mock_redis = double("Redis")
      described_class.configure do |config|
        config.redis_connection = mock_redis
      end

      expect(described_class.redis).to eq(mock_redis)
    end
  end

  describe ".reset_configuration!" do
    it "resets to default values" do
      described_class.configure do |config|
        config.default_delay = 999
      end

      described_class.reset_configuration!

      expect(described_class.configuration.default_delay).to eq(60)
    end
  end
end
