# frozen_string_literal: true

require_relative 'development/store'
require_relative 'development/logger'

module BrainzLab
  # Development mode support for offline SDK usage
  # Logs all events to stdout and stores them locally in SQLite
  module Development
    class << self
      # Check if development mode is enabled
      def enabled?
        BrainzLab.configuration.mode == :development
      end

      # Get the store instance
      def store
        @store ||= Store.new(BrainzLab.configuration)
      end

      # Get the development logger
      def logger
        @logger ||= Logger.new(output: BrainzLab.configuration.development_log_output || $stdout)
      end

      # Record an event from any service
      # @param service [Symbol] :recall, :reflex, :pulse, etc.
      # @param event_type [String] type of event (log, error, trace, metric, etc.)
      # @param payload [Hash] event data
      def record(service:, event_type:, payload:)
        return unless enabled?

        # Log to stdout
        logger.log(service: service, event_type: event_type, payload: payload)

        # Store in SQLite
        store.insert(service: service, event_type: event_type, payload: payload)
      end

      # Query stored events
      # @param service [Symbol, nil] filter by service
      # @param event_type [String, nil] filter by event type
      # @param since [Time, nil] filter events after this time
      # @param limit [Integer] max number of events to return (default: 100)
      # @return [Array<Hash>] matching events
      def events(service: nil, event_type: nil, since: nil, limit: 100)
        return [] unless enabled?

        store.query(service: service, event_type: event_type, since: since, limit: limit)
      end

      # Clear all stored events
      def clear!
        store.clear! if enabled?
      end

      # Reset the development module (for testing)
      def reset!
        @store&.close
        @store = nil
        @logger = nil
      end

      # Get event counts by service
      def stats
        return {} unless enabled?

        store.stats
      end
    end
  end
end
