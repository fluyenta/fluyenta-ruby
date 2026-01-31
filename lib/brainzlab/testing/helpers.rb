# frozen_string_literal: true

module BrainzLab
  module Testing
    # Test helpers for RSpec and Minitest
    #
    # Include this module in your test helper to gain access to
    # BrainzLab testing utilities.
    #
    # @example RSpec configuration
    #   RSpec.configure do |config|
    #     config.include BrainzLab::Testing::Helpers
    #
    #     config.before(:each) do
    #       stub_brainzlab!
    #     end
    #
    #     config.after(:each) do
    #       clear_brainzlab_events!
    #     end
    #   end
    #
    # @example Minitest configuration
    #   class ActiveSupport::TestCase
    #     include BrainzLab::Testing::Helpers
    #
    #     setup do
    #       stub_brainzlab!
    #     end
    #
    #     teardown do
    #       clear_brainzlab_events!
    #     end
    #   end
    #
    module Helpers
      # Stub all BrainzLab SDK calls to prevent real API requests
      # and enable event capturing for assertions.
      #
      # @example
      #   it 'tracks user signup' do
      #     stub_brainzlab!
      #     UserService.new.register(email: 'test@example.com')
      #     expect(brainzlab_events).to include(hash_including(name: 'user.signup'))
      #   end
      #
      def stub_brainzlab!
        BrainzLab::Testing.enable!
      end

      # Restore original BrainzLab SDK behavior
      #
      # @note This is typically called automatically if you're using
      #   clear_brainzlab_events! in your teardown, which also restores state.
      def unstub_brainzlab!
        BrainzLab::Testing.disable!
      end

      # Clear all captured events, logs, errors, and metrics
      #
      # Call this in your test teardown or between test scenarios
      # to ensure a clean slate.
      #
      # @example
      #   after(:each) do
      #     clear_brainzlab_events!
      #   end
      #
      def clear_brainzlab_events!
        BrainzLab::Testing.event_store.clear!
      end

      # Access all captured Flux events
      #
      # @return [Array<Hash>] Array of captured events
      #
      # @example
      #   brainzlab_events
      #   # => [{ name: 'user.signup', properties: { user_id: 1 }, timestamp: ... }]
      #
      def brainzlab_events
        BrainzLab::Testing.event_store.events
      end

      # Access events filtered by name
      #
      # @param name [String, Symbol] Event name to filter by
      # @return [Array<Hash>] Matching events
      #
      # @example
      #   brainzlab_events_named('user.signup')
      #   # => [{ name: 'user.signup', properties: { user_id: 1 }, timestamp: ... }]
      #
      def brainzlab_events_named(name)
        BrainzLab::Testing.event_store.events_named(name)
      end

      # Access all captured Flux metrics
      #
      # @return [Array<Hash>] Array of captured metrics
      #
      # @example
      #   brainzlab_metrics
      #   # => [{ type: :increment, name: 'orders.count', value: 1, tags: {} }]
      #
      def brainzlab_metrics
        BrainzLab::Testing.event_store.metrics
      end

      # Access all captured Recall logs
      #
      # @return [Array<Hash>] Array of captured log entries
      #
      # @example
      #   brainzlab_logs
      #   # => [{ level: :info, message: 'User created', data: { user_id: 1 } }]
      #
      def brainzlab_logs
        BrainzLab::Testing.event_store.logs
      end

      # Access logs filtered by level
      #
      # @param level [Symbol] Log level (:debug, :info, :warn, :error, :fatal)
      # @return [Array<Hash>] Matching log entries
      #
      def brainzlab_logs_at_level(level)
        BrainzLab::Testing.event_store.logs_at_level(level)
      end

      # Access all captured Reflex errors
      #
      # @return [Array<Hash>] Array of captured errors
      #
      # @example
      #   brainzlab_errors
      #   # => [{ exception: #<RuntimeError>, error_class: 'RuntimeError', message: 'Oops' }]
      #
      def brainzlab_errors
        BrainzLab::Testing.event_store.errors
      end

      # Access all captured Pulse traces
      #
      # @return [Array<Hash>] Array of captured traces
      #
      def brainzlab_traces
        BrainzLab::Testing.event_store.traces
      end

      # Access all captured Signal alerts
      #
      # @return [Array<Hash>] Array of captured alerts
      #
      def brainzlab_alerts
        BrainzLab::Testing.event_store.alerts
      end

      # Access all captured Signal notifications
      #
      # @return [Array<Hash>] Array of captured notifications
      #
      def brainzlab_notifications
        BrainzLab::Testing.event_store.notifications
      end

      # Check if a specific event was tracked
      #
      # @param name [String, Symbol] Event name
      # @param properties [Hash, nil] Optional properties to match
      # @return [Boolean]
      #
      # @example
      #   brainzlab_event_tracked?('user.signup')
      #   brainzlab_event_tracked?('user.signup', user_id: 1)
      #
      def brainzlab_event_tracked?(name, properties = nil)
        BrainzLab::Testing.event_store.event_tracked?(name, properties)
      end

      # Check if a specific metric was recorded
      #
      # @param type [Symbol] Metric type (:gauge, :increment, :distribution, etc.)
      # @param name [String, Symbol] Metric name
      # @param value [Numeric, nil] Optional value to match
      # @param tags [Hash, nil] Optional tags to match
      # @return [Boolean]
      #
      def brainzlab_metric_recorded?(type, name, value: nil, tags: nil)
        BrainzLab::Testing.event_store.metric_recorded?(type, name, value: value, tags: tags)
      end

      # Check if a specific log message was recorded
      #
      # @param level [Symbol] Log level
      # @param message [String, Regexp, nil] Optional message to match
      # @param data [Hash, nil] Optional data to match
      # @return [Boolean]
      #
      def brainzlab_logged?(level, message = nil, data = nil)
        BrainzLab::Testing.event_store.logged?(level, message, data)
      end

      # Check if a specific error was captured
      #
      # @param error_class [Class, String, nil] Error class to match
      # @param message [String, Regexp, nil] Optional message to match
      # @param context [Hash, nil] Optional context to match
      # @return [Boolean]
      #
      def brainzlab_error_captured?(error_class = nil, message: nil, context: nil)
        BrainzLab::Testing.event_store.error_captured?(error_class, message: message, context: context)
      end

      # Check if a specific trace was recorded
      #
      # @param name [String, Symbol] Trace name
      # @param opts [Hash, nil] Optional options to match
      # @return [Boolean]
      #
      def brainzlab_trace_recorded?(name, opts = nil)
        BrainzLab::Testing.event_store.trace_recorded?(name, opts)
      end

      # Check if a specific alert was sent
      #
      # @param name [String, Symbol] Alert name
      # @param message [String, nil] Optional message to match
      # @param severity [Symbol, nil] Optional severity to match
      # @return [Boolean]
      #
      def brainzlab_alert_sent?(name, message: nil, severity: nil)
        BrainzLab::Testing.event_store.alert_sent?(name, message: message, severity: severity)
      end

      # Get the last captured event
      #
      # @return [Hash, nil] The last event or nil
      #
      def last_brainzlab_event
        BrainzLab::Testing.event_store.last_event
      end

      # Get the last captured error
      #
      # @return [Hash, nil] The last error or nil
      #
      def last_brainzlab_error
        BrainzLab::Testing.event_store.last_error
      end

      # Create an event expectation builder for fluent assertions
      #
      # @param name [String, Symbol] Event name to expect
      # @return [EventExpectation] Expectation builder
      #
      # @example RSpec usage
      #   expect_brainzlab_event('user.signup').with(user_id: 1)
      #   expect_brainzlab_event('order.completed').with(order_id: 42, total: 99.99)
      #
      def expect_brainzlab_event(name)
        EventExpectation.new(name, BrainzLab::Testing.event_store)
      end

      # Create an error expectation builder for fluent assertions
      #
      # @param error_class [Class, String] Error class to expect
      # @return [ErrorExpectation] Expectation builder
      #
      # @example RSpec usage
      #   expect_brainzlab_error(RuntimeError).with_message(/something went wrong/i)
      #
      def expect_brainzlab_error(error_class)
        ErrorExpectation.new(error_class, BrainzLab::Testing.event_store)
      end

      # Create a log expectation builder for fluent assertions
      #
      # @param level [Symbol] Log level to expect
      # @return [LogExpectation] Expectation builder
      #
      # @example RSpec usage
      #   expect_brainzlab_log(:info).with_message('User created')
      #
      def expect_brainzlab_log(level)
        LogExpectation.new(level, BrainzLab::Testing.event_store)
      end

      # Create a metric expectation builder for fluent assertions
      #
      # @param type [Symbol] Metric type (:gauge, :increment, :distribution, etc.)
      # @param name [String, Symbol] Metric name
      # @return [MetricExpectation] Expectation builder
      #
      # @example RSpec usage
      #   expect_brainzlab_metric(:increment, 'orders.count').with_value(1)
      #
      def expect_brainzlab_metric(type, name)
        MetricExpectation.new(type, name, BrainzLab::Testing.event_store)
      end

      # Create a trace expectation builder for fluent assertions
      #
      # @param name [String, Symbol] Trace name to expect
      # @return [TraceExpectation] Expectation builder
      #
      # @example RSpec usage
      #   expect_brainzlab_trace('db.query')
      #
      def expect_brainzlab_trace(name)
        TraceExpectation.new(name, BrainzLab::Testing.event_store)
      end

      # Create an alert expectation builder for fluent assertions
      #
      # @param name [String, Symbol] Alert name to expect
      # @return [AlertExpectation] Expectation builder
      #
      # @example RSpec usage
      #   expect_brainzlab_alert('high_error_rate').with_severity(:critical)
      #
      def expect_brainzlab_alert(name)
        AlertExpectation.new(name, BrainzLab::Testing.event_store)
      end
    end

    # Fluent expectation builder for events
    class EventExpectation
      def initialize(name, store)
        @name = name.to_s
        @store = store
        @expected_properties = {}
      end

      # Specify expected properties
      #
      # @param properties [Hash] Properties to match
      # @return [self]
      #
      def with(properties = {})
        @expected_properties = properties
        self
      end

      # Check if the expectation is satisfied
      #
      # @return [Boolean]
      #
      def satisfied?
        @store.event_tracked?(@name, @expected_properties.empty? ? nil : @expected_properties)
      end

      # Alias for satisfied? (for RSpec matchers)
      alias matches? satisfied?

      # Get matching events
      #
      # @return [Array<Hash>]
      #
      def matching_events
        events = @store.events_named(@name)
        return events if @expected_properties.empty?

        events.select { |e| properties_match?(e[:properties], @expected_properties) }
      end

      # Failure message for RSpec
      def failure_message
        if @expected_properties.empty?
          "expected event '#{@name}' to be tracked, but it wasn't"
        else
          "expected event '#{@name}' with properties #{@expected_properties.inspect} to be tracked, " \
            "but got: #{@store.events_named(@name).map { |e| e[:properties] }.inspect}"
        end
      end

      # Negative failure message for RSpec
      def failure_message_when_negated
        if @expected_properties.empty?
          "expected event '#{@name}' not to be tracked, but it was"
        else
          "expected event '#{@name}' with properties #{@expected_properties.inspect} not to be tracked, but it was"
        end
      end

      private

      def properties_match?(actual, expected)
        expected.all? do |key, value|
          actual_value = actual[key] || actual[key.to_s] || actual[key.to_sym]
          case value
          when Regexp
            actual_value.to_s.match?(value)
          else
            actual_value == value
          end
        end
      end
    end

    # Fluent expectation builder for errors
    class ErrorExpectation
      def initialize(error_class, store)
        @error_class = error_class
        @store = store
        @expected_message = nil
        @expected_context = nil
      end

      # Specify expected message
      #
      # @param message [String, Regexp] Message to match
      # @return [self]
      #
      def with_message(message)
        @expected_message = message
        self
      end

      # Specify expected context
      #
      # @param context [Hash] Context to match
      # @return [self]
      #
      def with_context(context)
        @expected_context = context
        self
      end

      # Check if the expectation is satisfied
      #
      # @return [Boolean]
      #
      def satisfied?
        @store.error_captured?(@error_class, message: @expected_message, context: @expected_context)
      end

      alias matches? satisfied?

      def failure_message
        parts = ["expected error #{@error_class} to be captured"]
        parts << "with message matching #{@expected_message.inspect}" if @expected_message
        parts << "with context #{@expected_context.inspect}" if @expected_context
        parts << ", but got: #{@store.errors.map { |e| { class: e[:error_class], message: e[:message] } }.inspect}"
        parts.join
      end

      def failure_message_when_negated
        "expected error #{@error_class} not to be captured, but it was"
      end
    end

    # Fluent expectation builder for logs
    class LogExpectation
      def initialize(level, store)
        @level = level.to_sym
        @store = store
        @expected_message = nil
        @expected_data = nil
      end

      # Specify expected message
      #
      # @param message [String, Regexp] Message to match
      # @return [self]
      #
      def with_message(message)
        @expected_message = message
        self
      end

      # Specify expected data
      #
      # @param data [Hash] Data to match
      # @return [self]
      #
      def with_data(data)
        @expected_data = data
        self
      end

      # Check if the expectation is satisfied
      #
      # @return [Boolean]
      #
      def satisfied?
        @store.logged?(@level, @expected_message, @expected_data)
      end

      alias matches? satisfied?

      def failure_message
        parts = ["expected log at level :#{@level}"]
        parts << "with message matching #{@expected_message.inspect}" if @expected_message
        parts << "with data #{@expected_data.inspect}" if @expected_data
        parts << ", but got: #{@store.logs_at_level(@level).map { |l| { message: l[:message], data: l[:data] } }.inspect}"
        parts.join
      end

      def failure_message_when_negated
        "expected no log at level :#{@level} to be recorded, but it was"
      end
    end

    # Fluent expectation builder for metrics
    class MetricExpectation
      def initialize(type, name, store)
        @type = type.to_sym
        @name = name.to_s
        @store = store
        @expected_value = nil
        @expected_tags = nil
      end

      # Specify expected value
      #
      # @param value [Numeric] Value to match
      # @return [self]
      #
      def with_value(value)
        @expected_value = value
        self
      end

      # Specify expected tags
      #
      # @param tags [Hash] Tags to match
      # @return [self]
      #
      def with_tags(tags)
        @expected_tags = tags
        self
      end

      # Check if the expectation is satisfied
      #
      # @return [Boolean]
      #
      def satisfied?
        @store.metric_recorded?(@type, @name, value: @expected_value, tags: @expected_tags)
      end

      alias matches? satisfied?

      def failure_message
        parts = ["expected metric #{@type}('#{@name}')"]
        parts << "with value #{@expected_value.inspect}" if @expected_value
        parts << "with tags #{@expected_tags.inspect}" if @expected_tags
        parts << ", but got: #{@store.metrics_named(@name).inspect}"
        parts.join
      end

      def failure_message_when_negated
        "expected metric #{@type}('#{@name}') not to be recorded, but it was"
      end
    end

    # Fluent expectation builder for traces
    class TraceExpectation
      def initialize(name, store)
        @name = name.to_s
        @store = store
        @expected_opts = nil
      end

      # Specify expected options
      #
      # @param opts [Hash] Options to match
      # @return [self]
      #
      def with(opts)
        @expected_opts = opts
        self
      end

      # Check if the expectation is satisfied
      #
      # @return [Boolean]
      #
      def satisfied?
        @store.trace_recorded?(@name, @expected_opts)
      end

      alias matches? satisfied?

      def failure_message
        parts = ["expected trace '#{@name}'"]
        parts << "with options #{@expected_opts.inspect}" if @expected_opts
        parts << " to be recorded, but it wasn't"
        parts.join
      end

      def failure_message_when_negated
        "expected trace '#{@name}' not to be recorded, but it was"
      end
    end

    # Fluent expectation builder for alerts
    class AlertExpectation
      def initialize(name, store)
        @name = name.to_s
        @store = store
        @expected_message = nil
        @expected_severity = nil
      end

      # Specify expected message
      #
      # @param message [String] Message to match
      # @return [self]
      #
      def with_message(message)
        @expected_message = message
        self
      end

      # Specify expected severity
      #
      # @param severity [Symbol] Severity to match
      # @return [self]
      #
      def with_severity(severity)
        @expected_severity = severity
        self
      end

      # Check if the expectation is satisfied
      #
      # @return [Boolean]
      #
      def satisfied?
        @store.alert_sent?(@name, message: @expected_message, severity: @expected_severity)
      end

      alias matches? satisfied?

      def failure_message
        parts = ["expected alert '#{@name}'"]
        parts << "with message '#{@expected_message}'" if @expected_message
        parts << "with severity :#{@expected_severity}" if @expected_severity
        parts << " to be sent, but it wasn't"
        parts.join
      end

      def failure_message_when_negated
        "expected alert '#{@name}' not to be sent, but it was"
      end
    end
  end
end
