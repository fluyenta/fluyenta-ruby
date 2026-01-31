# frozen_string_literal: true

require_relative 'testing/event_store'
require_relative 'testing/helpers'
require_relative 'testing/matchers'

module BrainzLab
  # Testing utilities for BrainzLab SDK
  #
  # Provides helpers for stubbing SDK calls, capturing events,
  # and custom matchers for RSpec/Minitest.
  #
  # @example Usage in RSpec
  #   # spec/rails_helper.rb or spec/spec_helper.rb
  #   require 'brainzlab/testing'
  #
  #   RSpec.configure do |config|
  #     config.include BrainzLab::Testing::Helpers
  #   end
  #
  # @example Usage in Minitest
  #   # test/test_helper.rb
  #   require 'brainzlab/testing'
  #
  #   class ActiveSupport::TestCase
  #     include BrainzLab::Testing::Helpers
  #   end
  #
  module Testing
    class << self
      # Global event store for capturing events during tests
      def event_store
        @event_store ||= EventStore.new
      end

      # Reset the event store (called between tests)
      def reset!
        @event_store = EventStore.new
      end

      # Check if testing mode is active
      def enabled?
        @enabled == true
      end

      # Enable testing mode (stubs all SDK calls)
      def enable!
        return if @enabled

        @enabled = true
        install_stubs!
      end

      # Disable testing mode
      def disable!
        return unless @enabled

        @enabled = false
        remove_stubs!
      end

      private

      def install_stubs!
        # Stub Flux (events/metrics)
        stub_flux!

        # Stub Recall (logging)
        stub_recall!

        # Stub Reflex (error tracking)
        stub_reflex!

        # Stub Pulse (APM/tracing)
        stub_pulse!

        # Stub Signal (alerts/notifications)
        stub_signal!

        # Stub other modules
        stub_beacon!
        stub_nerve!
        stub_dendrite!
        stub_sentinel!
        stub_synapse!
        stub_cortex!
        stub_vault!
        stub_vision!
      end

      def remove_stubs!
        # Reset all modules to restore original behavior
        BrainzLab.reset_configuration!
      end

      def stub_flux!
        # Store original methods
        @original_flux_track = BrainzLab::Flux.method(:track)

        # Replace with capturing versions
        BrainzLab::Flux.define_singleton_method(:track) do |name, properties = {}|
          BrainzLab::Testing.event_store.record_event(name, properties)
        end

        BrainzLab::Flux.define_singleton_method(:track_for_user) do |user, name, properties = {}|
          user_id = user.respond_to?(:id) ? user.id.to_s : user.to_s
          BrainzLab::Testing.event_store.record_event(name, properties.merge(user_id: user_id))
        end

        # Stub metrics
        %i[gauge increment decrement distribution histogram timing set].each do |method|
          BrainzLab::Flux.define_singleton_method(method) do |name, value = nil, **opts|
            BrainzLab::Testing.event_store.record_metric(method, name, value, opts)
          end
        end

        BrainzLab::Flux.define_singleton_method(:measure) do |name, **opts, &block|
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = block.call
          duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
          BrainzLab::Testing.event_store.record_metric(:distribution, name, duration_ms, opts.merge(unit: 'ms'))
          result
        end

        BrainzLab::Flux.define_singleton_method(:flush!) { true }
      end

      def stub_recall!
        %i[debug info warn error fatal].each do |level|
          BrainzLab::Recall.define_singleton_method(level) do |message, **data|
            BrainzLab::Testing.event_store.record_log(level, message, data)
          end
        end

        BrainzLab::Recall.define_singleton_method(:log) do |level, message, **data|
          BrainzLab::Testing.event_store.record_log(level, message, data)
        end

        BrainzLab::Recall.define_singleton_method(:time) do |label, **data, &block|
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = block.call
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)
          BrainzLab::Testing.event_store.record_log(:info, "#{label} (#{duration_ms}ms)", data.merge(duration_ms: duration_ms))
          result
        end

        BrainzLab::Recall.define_singleton_method(:flush) { true }
      end

      def stub_reflex!
        BrainzLab::Reflex.define_singleton_method(:capture) do |exception, **context|
          BrainzLab::Testing.event_store.record_error(exception, context)
        end

        BrainzLab::Reflex.define_singleton_method(:capture_message) do |message, level: :error, **context|
          BrainzLab::Testing.event_store.record_error_message(message, level, context)
        end
      end

      def stub_pulse!
        # Stub tracing methods
        BrainzLab::Pulse.define_singleton_method(:start_trace) do |name, **opts|
          BrainzLab::Testing.event_store.record_trace(name, opts.merge(action: :start))
          { trace_id: 'test-trace-id-12345', name: name }
        end

        BrainzLab::Pulse.define_singleton_method(:finish_trace) do |**opts|
          BrainzLab::Testing.event_store.record_trace('finish', opts.merge(action: :finish))
          true
        end

        BrainzLab::Pulse.define_singleton_method(:span) do |name, **opts, &block|
          BrainzLab::Testing.event_store.record_trace(name, opts.merge(type: :span))
          block&.call
        end

        BrainzLab::Pulse.define_singleton_method(:record_trace) do |name, **opts|
          BrainzLab::Testing.event_store.record_trace(name, opts)
          true
        end

        BrainzLab::Pulse.define_singleton_method(:record_span) do |**opts|
          BrainzLab::Testing.event_store.record_trace(opts[:name], opts)
          true
        end

        BrainzLab::Pulse.define_singleton_method(:record_metric) do |name, **opts|
          BrainzLab::Testing.event_store.record_metric(opts[:kind] || :gauge, name, opts[:value], tags: opts[:tags] || {})
          true
        end

        # Stub metric convenience methods
        %i[gauge counter histogram].each do |method|
          BrainzLab::Pulse.define_singleton_method(method) do |name, value, tags: {}|
            BrainzLab::Testing.event_store.record_metric(method, name, value, tags: tags)
            true
          end
        end

        # Stub distributed tracing methods
        BrainzLab::Pulse.define_singleton_method(:inject) do |headers, **opts|
          headers['traceparent'] = '00-test-trace-id-12345-test-span-id-67890-01'
          headers
        end

        BrainzLab::Pulse.define_singleton_method(:extract) do |headers|
          BrainzLab::Pulse::Propagation::Context.new(
            trace_id: 'test-trace-id-12345',
            span_id: 'test-span-id-67890'
          ) if headers['traceparent']
        end

        BrainzLab::Pulse.define_singleton_method(:extract!) do |headers|
          BrainzLab::Pulse.extract(headers)
        end

        BrainzLab::Pulse.define_singleton_method(:propagation_context) do
          BrainzLab::Pulse::Propagation::Context.new(
            trace_id: 'test-trace-id-12345',
            span_id: 'test-span-id-67890'
          )
        end

        BrainzLab::Pulse.define_singleton_method(:child_context) do
          BrainzLab::Pulse::Propagation::Context.new(
            trace_id: 'test-trace-id-12345',
            span_id: SecureRandom.hex(8)
          )
        end
      end

      def stub_signal!
        BrainzLab::Signal.define_singleton_method(:alert) do |name, message, severity: :warning, channels: nil, data: {}|
          BrainzLab::Testing.event_store.record_alert(name, message, severity, channels, data)
        end

        BrainzLab::Signal.define_singleton_method(:notify) do |channel, message, title: nil, data: {}|
          BrainzLab::Testing.event_store.record_notification(channel, message, title, data)
        end

        BrainzLab::Signal.define_singleton_method(:trigger) do |rule_name, context = {}|
          BrainzLab::Testing.event_store.record_trigger(rule_name, context)
        end

        BrainzLab::Signal.define_singleton_method(:test!) { true }
      end

      def stub_beacon!
        return unless defined?(BrainzLab::Beacon)

        BrainzLab::Beacon.define_singleton_method(:create_http_monitor) { |*| { id: 'test-monitor-1', status: 'created' } }
        BrainzLab::Beacon.define_singleton_method(:create_ssl_monitor) { |*| { id: 'test-monitor-2', status: 'created' } }
        BrainzLab::Beacon.define_singleton_method(:create_tcp_monitor) { |*| { id: 'test-monitor-3', status: 'created' } }
        BrainzLab::Beacon.define_singleton_method(:create_dns_monitor) { |*| { id: 'test-monitor-4', status: 'created' } }
        BrainzLab::Beacon.define_singleton_method(:list) { [] }
        BrainzLab::Beacon.define_singleton_method(:get) { |_id| nil }
        BrainzLab::Beacon.define_singleton_method(:update) { |*| true }
        BrainzLab::Beacon.define_singleton_method(:delete) { |_id| true }
        BrainzLab::Beacon.define_singleton_method(:pause) { |_id| true }
        BrainzLab::Beacon.define_singleton_method(:resume) { |_id| true }
        BrainzLab::Beacon.define_singleton_method(:history) { |*| [] }
        BrainzLab::Beacon.define_singleton_method(:status) { { status: 'up', monitors: 0 } }
        BrainzLab::Beacon.define_singleton_method(:all_up?) { true }
        BrainzLab::Beacon.define_singleton_method(:incidents) { [] }
      end

      def stub_nerve!
        return unless defined?(BrainzLab::Nerve)

        BrainzLab::Nerve.define_singleton_method(:flag) { |*| false }
        BrainzLab::Nerve.define_singleton_method(:enabled?) { |*| false }
        BrainzLab::Nerve.define_singleton_method(:disabled?) { |*| true }
        BrainzLab::Nerve.define_singleton_method(:variation) { |*| nil }
        BrainzLab::Nerve.define_singleton_method(:all_flags) { {} }
      end

      def stub_dendrite!
        return unless defined?(BrainzLab::Dendrite)

        BrainzLab::Dendrite.define_singleton_method(:get) { |*| nil }
        BrainzLab::Dendrite.define_singleton_method(:set) { |*| true }
        BrainzLab::Dendrite.define_singleton_method(:delete) { |*| true }
        BrainzLab::Dendrite.define_singleton_method(:all) { {} }
      end

      def stub_sentinel!
        return unless defined?(BrainzLab::Sentinel)

        BrainzLab::Sentinel.define_singleton_method(:check) { |*| { allowed: true } }
        BrainzLab::Sentinel.define_singleton_method(:allowed?) { |*| true }
        BrainzLab::Sentinel.define_singleton_method(:denied?) { |*| false }
      end

      def stub_synapse!
        return unless defined?(BrainzLab::Synapse)

        BrainzLab::Synapse.define_singleton_method(:publish) { |*| true }
        BrainzLab::Synapse.define_singleton_method(:subscribe) { |*| true }
      end

      def stub_cortex!
        return unless defined?(BrainzLab::Cortex)

        BrainzLab::Cortex.define_singleton_method(:read) { |*| nil }
        BrainzLab::Cortex.define_singleton_method(:write) { |*| true }
        BrainzLab::Cortex.define_singleton_method(:delete) { |*| true }
        BrainzLab::Cortex.define_singleton_method(:fetch) { |key, **opts, &block| block&.call }
      end

      def stub_vault!
        return unless defined?(BrainzLab::Vault)

        BrainzLab::Vault.define_singleton_method(:get) { |*| nil }
        BrainzLab::Vault.define_singleton_method(:set) { |*| true }
        BrainzLab::Vault.define_singleton_method(:delete) { |*| true }
      end

      def stub_vision!
        return unless defined?(BrainzLab::Vision)

        BrainzLab::Vision.define_singleton_method(:track_pageview) { |*| true }
        BrainzLab::Vision.define_singleton_method(:track_event) { |*| true }
        BrainzLab::Vision.define_singleton_method(:identify) { |*| true }
      end
    end
  end
end
