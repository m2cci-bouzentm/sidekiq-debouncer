# frozen_string_literal: true

module Sidekiq
  module Debouncer
    class Configuration
      # Custom Redis connection. If not set, falls back to Redis.current
      attr_accessor :redis_connection

      # Default debounce delay in seconds (can be overridden per-job)
      attr_accessor :default_delay

      # Buffer time added to delay to prevent race conditions
      attr_accessor :buffer

      # TTL for Redis keys (cleanup safety net)
      attr_accessor :ttl

      def initialize
        @redis_connection = nil
        @default_delay = 60
        @buffer = 1
        @ttl = 60
      end
    end
  end
end
