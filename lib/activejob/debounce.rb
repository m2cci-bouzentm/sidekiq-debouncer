# frozen_string_literal: true

require_relative "debounce/version"
require_relative "debounce/configuration"
require_relative "debounce/concern"

module ActiveJob
  module Debounce
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
