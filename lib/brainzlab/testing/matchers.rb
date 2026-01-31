# frozen_string_literal: true

module BrainzLab
  module Testing
    # Custom RSpec matchers for BrainzLab SDK
    #
    # These matchers provide a clean, expressive syntax for testing
    # BrainzLab event tracking, error capture, logging, and metrics.
    #
    # @example Usage in RSpec
    #   RSpec.configure do |config|
    #     config.include BrainzLab::Testing::Matchers
    #   end
    #
    #   describe UserService do
    #     it 'tracks user signup' do
    #       subject.register(email: 'test@example.com')
    #       expect('user.signup').to have_been_tracked.with(email: 'test@example.com')
    #     end
    #   end
    #
    module Matchers
      # RSpec matcher for tracking events
      #
      # @example
      #   expect('user.signup').to have_been_tracked
      #   expect('user.signup').to have_been_tracked.with(user_id: 1)
      #   expect('order.completed').to have_been_tracked.with(order_id: 42, total: 99.99)
      #
      def have_been_tracked
        HaveBeenTrackedMatcher.new
      end

      # RSpec matcher for capturing errors
      #
      # @example
      #   expect(RuntimeError).to have_been_captured
      #   expect(RuntimeError).to have_been_captured.with_message(/something went wrong/i)
      #   expect('MyCustomError').to have_been_captured.with_context(user_id: 1)
      #
      def have_been_captured
        HaveBeenCapturedMatcher.new
      end

      # RSpec matcher for recording logs
      #
      # @example
      #   expect(:info).to have_been_logged.with_message('User created')
      #   expect(:error).to have_been_logged.with_message(/failed/i).with_data(user_id: 1)
      #
      def have_been_logged
        HaveBeenLoggedMatcher.new
      end

      # RSpec matcher for recording metrics
      #
      # @example
      #   expect(['increment', 'orders.count']).to have_been_recorded
      #   expect(['gauge', 'memory.usage']).to have_been_recorded.with_value(1024)
      #   expect(['distribution', 'response.time']).to have_been_recorded.with_tags(endpoint: '/api/users')
      #
      def have_been_recorded
        HaveBeenRecordedMatcher.new
      end

      # RSpec matcher for recording traces
      #
      # @example
      #   expect('db.query').to have_been_traced
      #   expect('http.request').to have_been_traced.with(method: 'GET')
      #
      def have_been_traced
        HaveBeenTracedMatcher.new
      end

      # RSpec matcher for sending alerts
      #
      # @example
      #   expect('high_error_rate').to have_sent_alert
      #   expect('low_disk_space').to have_sent_alert.with_severity(:critical)
      #
      def have_sent_alert
        HaveSentAlertMatcher.new
      end

      # Matcher for events
      class HaveBeenTrackedMatcher
        def initialize
          @expected_properties = {}
        end

        def with(properties)
          @expected_properties = properties
          self
        end

        def matches?(event_name)
          @event_name = event_name.to_s
          store = BrainzLab::Testing.event_store

          if @expected_properties.empty?
            store.event_tracked?(@event_name)
          else
            store.event_tracked?(@event_name, @expected_properties)
          end
        end

        def failure_message
          actual_events = BrainzLab::Testing.event_store.events_named(@event_name)

          if actual_events.empty?
            "expected event '#{@event_name}' to have been tracked, but no such event was found.\n" \
              "Tracked events: #{BrainzLab::Testing.event_store.events.map { |e| e[:name] }.inspect}"
          else
            "expected event '#{@event_name}' to have been tracked with properties:\n" \
              "  #{@expected_properties.inspect}\n" \
              "but was tracked with:\n" \
              "  #{actual_events.map { |e| e[:properties] }.inspect}"
          end
        end

        def failure_message_when_negated
          if @expected_properties.empty?
            "expected event '#{@event_name}' not to have been tracked, but it was"
          else
            "expected event '#{@event_name}' not to have been tracked with properties " \
              "#{@expected_properties.inspect}, but it was"
          end
        end

        def description
          desc = "have tracked event '#{@event_name}'"
          desc += " with properties #{@expected_properties.inspect}" unless @expected_properties.empty?
          desc
        end
      end

      # Matcher for errors
      class HaveBeenCapturedMatcher
        def initialize
          @expected_message = nil
          @expected_context = nil
        end

        def with_message(message)
          @expected_message = message
          self
        end

        def with_context(context)
          @expected_context = context
          self
        end

        def matches?(error_class)
          @error_class = error_class
          BrainzLab::Testing.event_store.error_captured?(
            @error_class,
            message: @expected_message,
            context: @expected_context
          )
        end

        def failure_message
          actual_errors = BrainzLab::Testing.event_store.errors

          if actual_errors.empty?
            "expected error #{@error_class} to have been captured, but no errors were captured"
          else
            msg = "expected error #{@error_class} to have been captured"
            msg += " with message matching #{@expected_message.inspect}" if @expected_message
            msg += " with context #{@expected_context.inspect}" if @expected_context
            msg + ", but captured errors were:\n  #{actual_errors.map { |e| { class: e[:error_class], message: e[:message] } }.inspect}"
          end
        end

        def failure_message_when_negated
          "expected error #{@error_class} not to have been captured, but it was"
        end

        def description
          desc = "have captured error #{@error_class}"
          desc += " with message #{@expected_message.inspect}" if @expected_message
          desc += " with context #{@expected_context.inspect}" if @expected_context
          desc
        end
      end

      # Matcher for logs
      class HaveBeenLoggedMatcher
        def initialize
          @expected_message = nil
          @expected_data = nil
        end

        def with_message(message)
          @expected_message = message
          self
        end

        def with_data(data)
          @expected_data = data
          self
        end

        def matches?(level)
          @level = level.to_sym
          BrainzLab::Testing.event_store.logged?(@level, @expected_message, @expected_data)
        end

        def failure_message
          actual_logs = BrainzLab::Testing.event_store.logs_at_level(@level)

          if actual_logs.empty?
            "expected a log at level :#{@level} to have been recorded, but none were found.\n" \
              "Available log levels: #{BrainzLab::Testing.event_store.logs.map { |l| l[:level] }.uniq.inspect}"
          else
            msg = "expected a log at level :#{@level}"
            msg += " with message matching #{@expected_message.inspect}" if @expected_message
            msg += " with data #{@expected_data.inspect}" if @expected_data
            msg + ", but logged messages were:\n  #{actual_logs.map { |l| { message: l[:message], data: l[:data] } }.inspect}"
          end
        end

        def failure_message_when_negated
          "expected no log at level :#{@level} to have been recorded, but it was"
        end

        def description
          desc = "have logged at level :#{@level}"
          desc += " with message #{@expected_message.inspect}" if @expected_message
          desc += " with data #{@expected_data.inspect}" if @expected_data
          desc
        end
      end

      # Matcher for metrics
      class HaveBeenRecordedMatcher
        def initialize
          @expected_value = nil
          @expected_tags = nil
        end

        def with_value(value)
          @expected_value = value
          self
        end

        def with_tags(tags)
          @expected_tags = tags
          self
        end

        def matches?(type_and_name)
          @type, @name = type_and_name
          @type = @type.to_sym
          @name = @name.to_s

          BrainzLab::Testing.event_store.metric_recorded?(
            @type,
            @name,
            value: @expected_value,
            tags: @expected_tags
          )
        end

        def failure_message
          actual_metrics = BrainzLab::Testing.event_store.metrics_named(@name)

          if actual_metrics.empty?
            "expected metric #{@type}('#{@name}') to have been recorded, but no such metric was found.\n" \
              "Recorded metrics: #{BrainzLab::Testing.event_store.metrics.map { |m| "#{m[:type]}('#{m[:name]}')" }.inspect}"
          else
            msg = "expected metric #{@type}('#{@name}')"
            msg += " with value #{@expected_value.inspect}" if @expected_value
            msg += " with tags #{@expected_tags.inspect}" if @expected_tags
            msg + ", but recorded metrics were:\n  #{actual_metrics.inspect}"
          end
        end

        def failure_message_when_negated
          "expected metric #{@type}('#{@name}') not to have been recorded, but it was"
        end

        def description
          desc = "have recorded metric #{@type}('#{@name}')"
          desc += " with value #{@expected_value.inspect}" if @expected_value
          desc += " with tags #{@expected_tags.inspect}" if @expected_tags
          desc
        end
      end

      # Matcher for traces
      class HaveBeenTracedMatcher
        def initialize
          @expected_opts = nil
        end

        def with(opts)
          @expected_opts = opts
          self
        end

        def matches?(trace_name)
          @trace_name = trace_name.to_s
          BrainzLab::Testing.event_store.trace_recorded?(@trace_name, @expected_opts)
        end

        def failure_message
          actual_traces = BrainzLab::Testing.event_store.traces

          if actual_traces.empty?
            "expected trace '#{@trace_name}' to have been recorded, but no traces were found"
          else
            msg = "expected trace '#{@trace_name}'"
            msg += " with options #{@expected_opts.inspect}" if @expected_opts
            msg + ", but recorded traces were:\n  #{actual_traces.map { |t| t[:name] }.inspect}"
          end
        end

        def failure_message_when_negated
          "expected trace '#{@trace_name}' not to have been recorded, but it was"
        end

        def description
          desc = "have traced '#{@trace_name}'"
          desc += " with #{@expected_opts.inspect}" if @expected_opts
          desc
        end
      end

      # Matcher for alerts
      class HaveSentAlertMatcher
        def initialize
          @expected_message = nil
          @expected_severity = nil
        end

        def with_message(message)
          @expected_message = message
          self
        end

        def with_severity(severity)
          @expected_severity = severity
          self
        end

        def matches?(alert_name)
          @alert_name = alert_name.to_s
          BrainzLab::Testing.event_store.alert_sent?(
            @alert_name,
            message: @expected_message,
            severity: @expected_severity
          )
        end

        def failure_message
          actual_alerts = BrainzLab::Testing.event_store.alerts

          if actual_alerts.empty?
            "expected alert '#{@alert_name}' to have been sent, but no alerts were found"
          else
            msg = "expected alert '#{@alert_name}'"
            msg += " with message '#{@expected_message}'" if @expected_message
            msg += " with severity :#{@expected_severity}" if @expected_severity
            msg + ", but sent alerts were:\n  #{actual_alerts.map { |a| { name: a[:name], severity: a[:severity] } }.inspect}"
          end
        end

        def failure_message_when_negated
          "expected alert '#{@alert_name}' not to have been sent, but it was"
        end

        def description
          desc = "have sent alert '#{@alert_name}'"
          desc += " with message '#{@expected_message}'" if @expected_message
          desc += " with severity :#{@expected_severity}" if @expected_severity
          desc
        end
      end
    end
  end
end

# Auto-register RSpec matchers if RSpec is loaded
if defined?(RSpec)
  RSpec.configure do |config|
    config.include BrainzLab::Testing::Matchers
  end
end
