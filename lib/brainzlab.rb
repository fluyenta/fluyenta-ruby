# frozen_string_literal: true

# BrainzLab SDK - Official Ruby SDK for BrainzLab products
#
# For testing utilities, require 'brainzlab/testing' in your test helper:
#
#   require 'brainzlab/testing'
#
#   RSpec.configure do |config|
#     config.include BrainzLab::Testing::Helpers
#   end
#
# See BrainzLab::Testing for more details.

require_relative 'brainzlab/version'
require_relative 'brainzlab/errors'
require_relative 'brainzlab/configuration'
require_relative 'brainzlab/debug'
require_relative 'brainzlab/context'
require_relative 'brainzlab/recall'
require_relative 'brainzlab/reflex'
require_relative 'brainzlab/pulse'
require_relative 'brainzlab/flux'
require_relative 'brainzlab/signal'
require_relative 'brainzlab/vault'
require_relative 'brainzlab/vision'
require_relative 'brainzlab/cortex'
require_relative 'brainzlab/beacon'
require_relative 'brainzlab/nerve'
require_relative 'brainzlab/dendrite'
require_relative 'brainzlab/sentinel'
require_relative 'brainzlab/synapse'
require_relative 'brainzlab/instrumentation'
require_relative 'brainzlab/utilities'
require_relative 'brainzlab/development'

module BrainzLab
  # Thread-local re-entrancy guard for instrumentation.
  # When true, SDK operations that would make HTTP calls are skipped
  # to prevent recursive instrumentation from blocking the host app.
  INSTRUMENTING_KEY = :brainzlab_instrumenting

  class << self
    # Returns true when inside an instrumentation handler.
    # Used by Recall.log, Pulse.record_metric, etc. to skip HTTP calls
    # that would block the host app during notification callbacks.
    def instrumenting?
      Thread.current[INSTRUMENTING_KEY] == true
    end

    # Executes a block within the instrumentation guard.
    # Prevents recursive/cascading SDK HTTP calls from instrumentation handlers.
    def with_instrumentation_guard
      return if Thread.current[INSTRUMENTING_KEY]

      Thread.current[INSTRUMENTING_KEY] = true
      begin
        yield
      ensure
        Thread.current[INSTRUMENTING_KEY] = nil
      end
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = Configuration.new
      Recall.reset!
      Reflex.reset!
      Pulse.reset!
      Flux.reset!
      Signal.reset!
      Vault.reset!
      Vision.reset!
      Cortex.reset!
      Beacon.reset!
      Nerve.reset!
      Dendrite.reset!
      Sentinel.reset!
      Synapse.reset!
      Development.reset!
    end

    # Context management
    def set_user(id: nil, email: nil, name: nil, **extra)
      Context.current.set_user(id: id, email: email, name: name, **extra)
    end

    def set_context(**data)
      Context.current.set_context(**data)
    end

    def set_tags(**data)
      Context.current.set_tags(**data)
    end

    def with_context(**data, &)
      Context.current.with_context(**data, &)
    end

    def clear_context!
      Context.clear!
    end

    # Breadcrumb helpers
    def add_breadcrumb(message, category: 'default', level: :info, data: nil)
      Reflex.add_breadcrumb(message, category: category, level: level, data: data)
    end

    def clear_breadcrumbs!
      Reflex.clear_breadcrumbs!
    end

    # Create a logger that can replace Rails.logger
    # @param broadcast_to [Logger] Optional logger to also send logs to (e.g., original Rails.logger)
    # @return [BrainzLab::Recall::Logger]
    def logger(broadcast_to: nil)
      Recall::Logger.new(nil, broadcast_to: broadcast_to)
    end

    # Debug logging helper
    def debug_log(message)
      configuration.debug_log(message)
    end

    # Check if debug mode is enabled
    def debug?
      configuration.debug?
    end

    # Query events stored in development mode
    # @param service [Symbol, nil] filter by service (:recall, :reflex, :pulse, etc.)
    # @param event_type [String, nil] filter by event type ('log', 'error', 'trace', etc.)
    # @param since [Time, nil] filter events after this time
    # @param limit [Integer] max number of events to return (default: 100)
    # @return [Array<Hash>] matching events
    # @example
    #   BrainzLab.development_events                              # All events
    #   BrainzLab.development_events(service: :recall)            # Only Recall logs
    #   BrainzLab.development_events(service: :reflex, limit: 10) # Last 10 errors
    #   BrainzLab.development_events(since: 1.hour.ago)           # Events from last hour
    def development_events(service: nil, event_type: nil, since: nil, limit: 100)
      Development.events(service: service, event_type: event_type, since: since, limit: limit)
    end

    # Clear all events stored in development mode
    def clear_development_events!
      Development.clear!
    end

    # Get stats about stored development events
    # @return [Hash] counts by service
    def development_stats
      Development.stats
    end

    # Health check - verifies connectivity to all enabled services
    # @return [Hash] Status of each service
    def health_check
      results = { status: 'ok', services: {} }

      # Check Recall
      if configuration.recall_enabled
        results[:services][:recall] = check_service_health(
          url: configuration.recall_url,
          name: 'Recall'
        )
      end

      # Check Reflex
      if configuration.reflex_enabled
        results[:services][:reflex] = check_service_health(
          url: configuration.reflex_url,
          name: 'Reflex'
        )
      end

      # Check Pulse
      if configuration.pulse_enabled
        results[:services][:pulse] = check_service_health(
          url: configuration.pulse_url,
          name: 'Pulse'
        )
      end

      # Check Flux
      if configuration.flux_enabled
        results[:services][:flux] = check_service_health(
          url: configuration.flux_url,
          name: 'Flux'
        )
      end

      # Check Signal
      if configuration.signal_enabled
        results[:services][:signal] = check_service_health(
          url: configuration.signal_url,
          name: 'Signal'
        )
      end

      # Check Vault
      if configuration.vault_enabled
        results[:services][:vault] = check_service_health(
          url: configuration.vault_url,
          name: 'Vault'
        )
      end

      # Check Vision
      if configuration.vision_enabled
        results[:services][:vision] = check_service_health(
          url: configuration.vision_url,
          name: 'Vision'
        )
      end

      # Check Cortex
      if configuration.cortex_enabled
        results[:services][:cortex] = check_service_health(
          url: configuration.cortex_url,
          name: 'Cortex'
        )
      end

      # Check Beacon
      if configuration.beacon_enabled
        results[:services][:beacon] = check_service_health(
          url: configuration.beacon_url,
          name: 'Beacon'
        )
      end

      # Check Nerve
      if configuration.nerve_enabled
        results[:services][:nerve] = check_service_health(
          url: configuration.nerve_url,
          name: 'Nerve'
        )
      end

      # Check Dendrite
      if configuration.dendrite_enabled
        results[:services][:dendrite] = check_service_health(
          url: configuration.dendrite_url,
          name: 'Dendrite'
        )
      end

      # Check Sentinel
      if configuration.sentinel_enabled
        results[:services][:sentinel] = check_service_health(
          url: configuration.sentinel_url,
          name: 'Sentinel'
        )
      end

      # Check Synapse
      if configuration.synapse_enabled
        results[:services][:synapse] = check_service_health(
          url: configuration.synapse_url,
          name: 'Synapse'
        )
      end

      # Overall status
      has_failure = results[:services].values.any? { |s| s[:status] == 'error' }
      results[:status] = has_failure ? 'degraded' : 'ok'

      results
    end

    private

    def check_service_health(url:, name:)
      require 'net/http'
      require 'uri'

      uri = URI.parse("#{url}/up")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 5
      http.read_timeout = 5

      response = http.get(uri.request_uri)

      if response.is_a?(Net::HTTPSuccess)
        { status: 'ok', latency_ms: 0 }
      else
        { status: 'error', message: "HTTP #{response.code}" }
      end
    rescue StandardError => e
      { status: 'error', message: e.message }
    end
  end
end

# Auto-load Rails integration if Rails is available
require_relative 'brainzlab/rails/railtie' if defined?(Rails::Railtie)
