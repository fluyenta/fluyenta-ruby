# frozen_string_literal: true

require 'json'

module BrainzLab
  module Development
    # Pretty-prints development mode events to stdout
    class Logger
      # ANSI color codes
      COLORS = {
        reset: "\e[0m",
        bold: "\e[1m",
        dim: "\e[2m",
        # Services
        recall: "\e[36m",     # Cyan
        reflex: "\e[31m",     # Red
        pulse: "\e[33m",      # Yellow
        flux: "\e[35m",       # Magenta
        signal: "\e[32m",     # Green
        vault: "\e[34m",      # Blue
        vision: "\e[95m",     # Light magenta
        cortex: "\e[96m",     # Light cyan
        beacon: "\e[92m",     # Light green
        nerve: "\e[93m",      # Light yellow
        dendrite: "\e[94m",   # Light blue
        sentinel: "\e[91m",   # Light red
        synapse: "\e[97m",    # White
        # Log levels
        debug: "\e[37m",      # Gray
        info: "\e[32m",       # Green
        warn: "\e[33m",       # Yellow
        error: "\e[31m",      # Red
        fatal: "\e[35m"       # Magenta
      }.freeze

      def initialize(output: $stdout, colors: nil)
        @output = output
        @colors = colors.nil? ? tty? : colors
      end

      # Log an event to stdout in a readable format
      # @param service [Symbol] :recall, :reflex, :pulse, etc.
      # @param event_type [String] type of event
      # @param payload [Hash] event data
      def log(service:, event_type:, payload:)
        timestamp = Time.now.strftime('%H:%M:%S.%L')
        service_color = COLORS[service] || COLORS[:reset]

        # Build the log line
        parts = []
        parts << colorize("[#{timestamp}]", :dim)
        parts << colorize("[#{service.to_s.upcase}]", service_color, bold: true)
        parts << colorize(event_type, :bold)

        # Add message or name depending on event type
        message = extract_message(payload, event_type)
        parts << message if message

        # Print the main line
        @output.puts parts.join(' ')

        # Print additional details indented
        print_details(payload, event_type)
      end

      private

      def tty?
        @output.respond_to?(:tty?) && @output.tty?
      end

      def colorize(text, color, bold: false)
        return text unless @colors

        color_code = color.is_a?(Symbol) ? COLORS[color] : color
        prefix = bold ? "#{COLORS[:bold]}#{color_code}" : color_code.to_s
        "#{prefix}#{text}#{COLORS[:reset]}"
      end

      def extract_message(payload, event_type)
        case event_type
        when 'log'
          level = payload[:level]&.to_sym
          level_color = COLORS[level] || COLORS[:info]
          msg = "#{colorize("[#{level&.upcase}]", level_color)} #{payload[:message]}"
          msg
        when 'error'
          "#{payload[:error_class]}: #{payload[:message]}"
        when 'trace'
          duration = payload[:duration_ms] ? "(#{payload[:duration_ms]}ms)" : ''
          "#{payload[:name]} #{duration}"
        when 'metric'
          "#{payload[:name]} = #{payload[:value]}"
        when 'span'
          duration = payload[:duration_ms] ? "(#{payload[:duration_ms]}ms)" : ''
          "#{payload[:name]} #{duration}"
        else
          payload[:message] || payload[:name]
        end
      end

      def print_details(payload, event_type)
        details = extract_details(payload, event_type)
        return if details.empty?

        details.each do |key, value|
          formatted_value = format_value(value)
          @output.puts "  #{colorize(key.to_s, :dim)}: #{formatted_value}"
        end
      end

      def extract_details(payload, event_type)
        # Fields to exclude from details (already shown in main line)
        excluded = %i[timestamp message level name kind]

        case event_type
        when 'log'
          payload.except(*excluded, :environment, :service, :host)
        when 'error'
          payload.slice(:error_class, :environment, :request_id, :user, :tags).compact
        when 'trace'
          payload.slice(:request_method, :request_path, :status, :db_ms, :view_ms, :spans).compact
        when 'metric'
          payload.slice(:kind, :tags).compact
        else
          payload.except(*excluded)
        end
      end

      def format_value(value)
        case value
        when Hash
          if value.size <= 3
            value.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')
          else
            "\n    #{JSON.pretty_generate(value).gsub("\n", "\n    ")}"
          end
        when Array
          if value.size <= 3 && value.all? { |v| v.is_a?(String) || v.is_a?(Numeric) }
            value.inspect
          else
            "\n    #{JSON.pretty_generate(value).gsub("\n", "\n    ")}"
          end
        else
          value.inspect
        end
      end
    end
  end
end
