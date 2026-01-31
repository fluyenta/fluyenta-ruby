# frozen_string_literal: true

module BrainzLab
  module Testing
    # Thread-safe store for captured events, logs, errors, and metrics during tests
    #
    # This class is used internally by the testing helpers to store all
    # captured data from stubbed SDK calls.
    class EventStore
      def initialize
        @mutex = Mutex.new
        @events = []
        @metrics = []
        @logs = []
        @errors = []
        @error_messages = []
        @traces = []
        @alerts = []
        @notifications = []
        @triggers = []
      end

      # === Events (Flux) ===

      def record_event(name, properties = {})
        @mutex.synchronize do
          @events << {
            name: name.to_s,
            properties: properties,
            timestamp: Time.now.utc
          }
        end
      end

      def events
        @mutex.synchronize { @events.dup }
      end

      def events_named(name)
        @mutex.synchronize do
          @events.select { |e| e[:name] == name.to_s }
        end
      end

      def event_tracked?(name, properties = nil)
        @mutex.synchronize do
          @events.any? do |event|
            next false unless event[:name] == name.to_s
            next true if properties.nil?

            properties_match?(event[:properties], properties)
          end
        end
      end

      def last_event
        @mutex.synchronize { @events.last }
      end

      def clear_events!
        @mutex.synchronize { @events.clear }
      end

      # === Metrics (Flux) ===

      def record_metric(type, name, value, opts = {})
        @mutex.synchronize do
          @metrics << {
            type: type.to_sym,
            name: name.to_s,
            value: value,
            tags: opts[:tags] || {},
            timestamp: Time.now.utc
          }
        end
      end

      def metrics
        @mutex.synchronize { @metrics.dup }
      end

      def metrics_named(name)
        @mutex.synchronize do
          @metrics.select { |m| m[:name] == name.to_s }
        end
      end

      def metric_recorded?(type, name, value: nil, tags: nil)
        @mutex.synchronize do
          @metrics.any? do |metric|
            next false unless metric[:type] == type.to_sym
            next false unless metric[:name] == name.to_s
            next false if value && metric[:value] != value
            next false if tags && !properties_match?(metric[:tags], tags)

            true
          end
        end
      end

      def clear_metrics!
        @mutex.synchronize { @metrics.clear }
      end

      # === Logs (Recall) ===

      def record_log(level, message, data = {})
        @mutex.synchronize do
          @logs << {
            level: level.to_sym,
            message: message.to_s,
            data: data,
            timestamp: Time.now.utc
          }
        end
      end

      def logs
        @mutex.synchronize { @logs.dup }
      end

      def logs_at_level(level)
        @mutex.synchronize do
          @logs.select { |l| l[:level] == level.to_sym }
        end
      end

      def logged?(level, message = nil, data = nil)
        @mutex.synchronize do
          @logs.any? do |log|
            next false unless log[:level] == level.to_sym
            next true if message.nil?

            message_matches = case message
                              when Regexp
                                log[:message].match?(message)
                              else
                                log[:message].include?(message.to_s)
                              end

            next false unless message_matches
            next true if data.nil?

            properties_match?(log[:data], data)
          end
        end
      end

      def clear_logs!
        @mutex.synchronize { @logs.clear }
      end

      # === Errors (Reflex) ===

      def record_error(exception, context = {})
        @mutex.synchronize do
          @errors << {
            exception: exception,
            error_class: exception.class.name,
            message: exception.message,
            backtrace: exception.backtrace,
            context: context,
            timestamp: Time.now.utc
          }
        end
      end

      def record_error_message(message, level, context = {})
        @mutex.synchronize do
          @error_messages << {
            message: message.to_s,
            level: level.to_sym,
            context: context,
            timestamp: Time.now.utc
          }
        end
      end

      def errors
        @mutex.synchronize { @errors.dup }
      end

      def error_messages
        @mutex.synchronize { @error_messages.dup }
      end

      def error_captured?(error_class = nil, message: nil, context: nil)
        @mutex.synchronize do
          @errors.any? do |error|
            if error_class
              next false unless error[:error_class] == error_class.to_s ||
                                (error_class.is_a?(Class) && error[:exception].is_a?(error_class))
            end

            if message
              message_matches = case message
                                when Regexp
                                  error[:message].match?(message)
                                else
                                  error[:message].include?(message.to_s)
                                end
              next false unless message_matches
            end

            next false if context && !properties_match?(error[:context], context)

            true
          end
        end
      end

      def last_error
        @mutex.synchronize { @errors.last }
      end

      def clear_errors!
        @mutex.synchronize do
          @errors.clear
          @error_messages.clear
        end
      end

      # === Traces (Pulse) ===

      def record_trace(name, opts = {})
        @mutex.synchronize do
          @traces << {
            name: name.to_s,
            options: opts,
            timestamp: Time.now.utc
          }
        end
      end

      def traces
        @mutex.synchronize { @traces.dup }
      end

      def trace_recorded?(name, opts = nil)
        @mutex.synchronize do
          @traces.any? do |trace|
            next false unless trace[:name] == name.to_s
            next true if opts.nil?

            properties_match?(trace[:options], opts)
          end
        end
      end

      def clear_traces!
        @mutex.synchronize { @traces.clear }
      end

      # === Alerts (Signal) ===

      def record_alert(name, message, severity, channels, data)
        @mutex.synchronize do
          @alerts << {
            name: name.to_s,
            message: message.to_s,
            severity: severity.to_sym,
            channels: channels,
            data: data,
            timestamp: Time.now.utc
          }
        end
      end

      def alerts
        @mutex.synchronize { @alerts.dup }
      end

      def alert_sent?(name, message: nil, severity: nil)
        @mutex.synchronize do
          @alerts.any? do |alert|
            next false unless alert[:name] == name.to_s
            next false if message && !alert[:message].include?(message.to_s)
            next false if severity && alert[:severity] != severity.to_sym

            true
          end
        end
      end

      def clear_alerts!
        @mutex.synchronize { @alerts.clear }
      end

      # === Notifications (Signal) ===

      def record_notification(channel, message, title, data)
        @mutex.synchronize do
          @notifications << {
            channel: Array(channel).map(&:to_s),
            message: message.to_s,
            title: title,
            data: data,
            timestamp: Time.now.utc
          }
        end
      end

      def notifications
        @mutex.synchronize { @notifications.dup }
      end

      def clear_notifications!
        @mutex.synchronize { @notifications.clear }
      end

      # === Triggers (Signal) ===

      def record_trigger(rule_name, context)
        @mutex.synchronize do
          @triggers << {
            rule_name: rule_name.to_s,
            context: context,
            timestamp: Time.now.utc
          }
        end
      end

      def triggers
        @mutex.synchronize { @triggers.dup }
      end

      def clear_triggers!
        @mutex.synchronize { @triggers.clear }
      end

      # === General ===

      def clear!
        @mutex.synchronize do
          @events.clear
          @metrics.clear
          @logs.clear
          @errors.clear
          @error_messages.clear
          @traces.clear
          @alerts.clear
          @notifications.clear
          @triggers.clear
        end
      end

      def empty?
        @mutex.synchronize do
          @events.empty? &&
            @metrics.empty? &&
            @logs.empty? &&
            @errors.empty? &&
            @error_messages.empty? &&
            @traces.empty? &&
            @alerts.empty? &&
            @notifications.empty? &&
            @triggers.empty?
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
  end
end
