# frozen_string_literal: true

require "active_support/concern"

module Sidekiq
  module Debouncer
    # Include this concern in your ActiveJob classes to add debouncing behavior.
    #
    # When multiple calls to `perform_debounce` are made with the same arguments
    # within the debounce window, only ONE job will be queued and executed.
    #
    # This is useful for:
    # - Avoiding rate limits on external APIs (HubSpot, Stripe, etc.)
    # - Batching rapid updates into a single operation
    # - Preventing redundant background work
    #
    # @example Basic usage
    #   class SyncUserJob < ApplicationJob
    #     include Sidekiq::Debouncer::Concern
    #
    #     debounce_for 30.seconds
    #
    #     def perform(user_id)
    #       # This will only run once per 30-second window per user_id
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

        # Clean up Redis key after job execution
        after_perform do |job|
          if self.class.debounce_settings.present?
            Sidekiq::Debouncer.redis.del(self.class.debounce_key(job.arguments))
          end
        end
      end

      class_methods do
        # Configure the debounce duration for this job class.
        #
        # @param duration [Integer, ActiveSupport::Duration] The debounce window
        # @example
        #   debounce_for 30.seconds
        #   debounce_for 2.minutes
        #   debounce_for 60 # 60 seconds
        #
        def debounce_for(duration)
          self.debounce_settings = { duration: duration.to_i }
        end

        # Alias for backwards compatibility
        alias_method :debounce_for_seconds, :debounce_for

        # Queue a debounced job. If called multiple times with the same arguments
        # within the debounce window, only one job will be queued.
        #
        # @param params [Array] The arguments to pass to the job's perform method
        # @return [void]
        #
        # @example
        #   UpdateTicketJob.perform_debounce(ticket_id)
        #   SyncJob.perform_debounce(record_id, "option1", "option2")
        #
        def perform_debounce(*params)
          delay = debounce_settings[:duration] || config.default_delay
          buffer = config.buffer
          ttl = config.ttl
          redis_key = debounce_key(params)

          # Atomically set new timestamp and get old value
          # GETSET returns old value; nil means no job was pending
          scheduled_at = current_timestamp + delay
          old_timestamp = Sidekiq::Debouncer.redis.getset(redis_key, scheduled_at)
          Sidekiq::Debouncer.redis.expire(redis_key, delay + buffer + ttl)

          # Determine if we should queue a new job
          no_job_pending = old_timestamp.nil?
          timestamp_expired = old_timestamp.to_i <= current_timestamp

          should_queue = no_job_pending || timestamp_expired
          return unless should_queue

          # Schedule the job with debounce delay + buffer
          # Buffer prevents race condition between GETSET and scheduling
          set(wait: delay + buffer).perform_later(*params)
        end

        # Generate a unique Redis key for this job + arguments combination.
        #
        # @param params [Array] The job arguments
        # @return [String] The Redis key
        #
        # @example
        #   UpdateTicketJob.debounce_key([123])
        #   # => "sidekiq_debouncer:UpdateTicketJob:123"
        #
        def debounce_key(params)
          params_list = Array.wrap(params).map do |param|
            # Support Rails GlobalID for ActiveRecord objects
            param.respond_to?(:to_global_id) ? param.to_global_id.to_s : param.to_s
          end

          key_string = params_list.join(":")
          "sidekiq_debouncer:#{name}:#{key_string}"
        end

        private

        def config
          Sidekiq::Debouncer.configuration
        end

        def current_timestamp
          Time.now.to_i
        end
      end
    end
  end
end
