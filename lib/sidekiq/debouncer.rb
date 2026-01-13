# frozen_string_literal: true

require_relative "debouncer/version"
require_relative "debouncer/configuration"
require_relative "debouncer/concern"

module Sidekiq
  module Debouncer
    class Error < StandardError; end

    class << self
      attr_writer :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def reset_configuration!
        @configuration = Configuration.new
      end

      def redis
        configuration.redis_connection || Redis.current
      end
    end
  end
end
