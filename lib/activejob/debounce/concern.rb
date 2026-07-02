# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/array/wrap"
require "active_support/core_ext/object/blank"

module ActiveJob
  module Debounce
    # Include this concern in your ActiveJob classes to add debouncing behavior.
    #
    # When multiple calls to `perform_debounce` are made with the same arguments
    # within the debounce window, only ONE job will be queued and executed.
    #
    # Works with any ActiveJob backend: Sidekiq, GoodJob, Solid Queue, Resque, etc.
    #
    # @example Basic usage
    #   class SyncUserJob < ApplicationJob
    #     include ActiveJob::Debounce::Concern
    #
    #     debounce_for 30.seconds
    #
    #     def perform(user_id)
    #       User.find(user_id).sync_to_crm
    #     end
    #   end
    #
    #   # Call it multiple times - only one job executes
    #   10.times { SyncUserJob.perform_debounce(user.id) }
    #
    module Concern
      extend ActiveSupport::Concern

      included do
        class_attribute :debounce_settings, default: {}

        after_perform do |job|
          if self.class.debounce_settings.present?
            ActiveJob::Debounce.redis.del(self.class.debounce_key(job.arguments))
          end
        end
      end

      class_methods do
        # Configure the debounce duration for this job class.
        #
        # @param duration [Integer, ActiveSupport::Duration] The debounce window
        def debounce_for(duration)
          self.debounce_settings = { duration: duration.to_i }
        end

        alias_method :debounce_for_seconds, :debounce_for

        # Queue a debounced job. If called multiple times with the same arguments
        # within the debounce window, only one job will be queued.
        #
        # @param params [Array] The arguments to pass to the job's perform method
        def perform_debounce(*params)
          delay = debounce_settings[:duration] || config.default_delay
          buffer = config.buffer
          ttl = config.ttl
          redis_key = debounce_key(params)

          # Atomic: set new timestamp, get old value
          scheduled_at = current_timestamp + delay
          old_timestamp = ActiveJob::Debounce.redis.getset(redis_key, scheduled_at)
          ActiveJob::Debounce.redis.expire(redis_key, delay + buffer + ttl)

          no_job_pending = old_timestamp.nil?
          timestamp_expired = old_timestamp.to_i <= current_timestamp
          should_queue = no_job_pending || timestamp_expired

          return unless should_queue

          set(wait: delay + buffer).perform_later(*params)
        end

        # Generate a unique Redis key for this job + arguments combination.
        #
        # @param params [Array] The job arguments
        # @return [String] The Redis key
        def debounce_key(params)
          params_list = Array.wrap(params).map do |param|
            param.respond_to?(:to_global_id) ? param.to_global_id.to_s : param.to_s
          end

          key_string = params_list.join(":")
          "activejob_debounce:#{name}:#{key_string}"
        end

        private

        def config
          ActiveJob::Debounce.configuration
        end

        def current_timestamp
          Time.now.to_i
        end
      end
    end
  end
end
