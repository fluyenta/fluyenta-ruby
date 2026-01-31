# frozen_string_literal: true

module BrainzLab
  # Debug module for SDK operation logging
  #
  # Provides pretty-printed debug output for all SDK operations when debug mode is enabled.
  # Includes timing information and request/response details.
  #
  # @example Enable debug mode
  #   BrainzLab.configure do |config|
  #     config.debug = true
  #   end
  #
  # @example Use custom logger
  #   BrainzLab.configure do |config|
  #     config.debug = true
  #     config.logger = Logger.new(STDOUT)
  #   end
  #
  # @example Manual debug logging
  #   BrainzLab::Debug.log("Custom message", level: :info)
  #
  module Debug
    COLORS = {
      reset: "\e[0m",
      bold: "\e[1m",
      dim: "\e[2m",
      red: "\e[31m",
      green: "\e[32m",
      yellow: "\e[33m",
      blue: "\e[34m",
      magenta: "\e[35m",
      cyan: "\e[36m",
      white: "\e[37m",
      gray: "\e[90m"
    }.freeze

    LEVEL_COLORS = {
      debug: :gray,
      info: :cyan,
      warn: :yellow,
      error: :red,
      fatal: :red
    }.freeze

    LEVEL_LABELS = {
      debug: 'DEBUG',
      info: 'INFO',
      warn: 'WARN',
      error: 'ERROR',
      fatal: 'FATAL'
    }.freeze

    class << self
      # Log a debug message if debug mode is enabled
      #
      # @param message [String] The message to log
      # @param level [Symbol] Log level (:debug, :info, :warn, :error, :fatal)
      # @param data [Hash] Optional additional data to include
      # @return [void]
      def log(message, level: :info, **data)
        return unless enabled?

        output = format_message(message, level: level, **data)
        write_output(output, level: level)
      end

      # Log an outgoing request
      #
      # @param service [String, Symbol] The service name (e.g., :recall, :reflex)
      # @param method [String] HTTP method
      # @param path [String] Request path
      # @param data [Hash] Request payload summary
      # @return [void]
      def log_request(service, method, path, data: nil)
        return unless enabled?

        data_summary = summarize_data(data) if data
        message = data_summary ? "#{method} #{path} #{data_summary}" : "#{method} #{path}"

        output = format_arrow_message(:out, service, message)
        write_output(output, level: :info)
      end

      # Log an incoming response
      #
      # @param service [String, Symbol] The service name
      # @param status [Integer] HTTP status code
      # @param duration_ms [Float] Request duration in milliseconds
      # @param error [String, nil] Error message if request failed
      # @return [void]
      def log_response(service, status, duration_ms, error: nil)
        return unless enabled?

        status_text = status_message(status)
        duration_text = format_duration(duration_ms)

        message = if error
                    "#{status} #{status_text} (#{duration_text}) - #{error}"
                  else
                    "#{status} #{status_text} (#{duration_text})"
                  end

        level = status >= 400 ? :error : :info
        output = format_arrow_message(:in, service, message, level: level)
        write_output(output, level: level)
      end

      # Log an SDK operation with timing
      #
      # @param service [String, Symbol] The service name
      # @param operation [String] Operation description
      # @param data [Hash] Operation data
      # @return [void]
      def log_operation(service, operation, **data)
        return unless enabled?

        data_summary = data.empty? ? '' : " (#{format_data_inline(data)})"
        message = "#{operation}#{data_summary}"

        output = format_arrow_message(:out, service, message)
        write_output(output, level: :info)
      end

      # Measure and log execution time of a block
      #
      # @param service [String, Symbol] The service name
      # @param operation [String] Operation description
      # @yield Block to measure
      # @return [Object] Result of the block
      def measure(service, operation)
        return yield unless enabled?

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        log_operation(service, operation)

        result = yield

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        log("#{operation} completed", level: :debug, duration_ms: duration_ms, service: service.to_s)

        result
      rescue StandardError => e
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        log("#{operation} failed: #{e.message}", level: :error, duration_ms: duration_ms, service: service.to_s)
        raise
      end

      # Check if debug mode is enabled
      #
      # @return [Boolean]
      def enabled?
        BrainzLab.configuration.debug?
      end

      # Check if colorized output should be used
      #
      # @return [Boolean]
      def colorize?
        return false unless enabled?
        return @colorize if defined?(@colorize)

        @colorize = $stdout.tty?
      end

      # Reset colorize detection (useful for testing)
      def reset_colorize!
        remove_instance_variable(:@colorize) if defined?(@colorize)
      end

      private

      def format_message(message, level:, **data)
        timestamp = format_timestamp
        prefix = colorize("[BrainzLab]", :bold, :blue)
        level_badge = format_level(level)
        data_str = data.empty? ? '' : " #{format_data(data)}"

        "#{prefix} #{timestamp} #{level_badge} #{message}#{data_str}"
      end

      def format_arrow_message(direction, service, message, level: :info)
        timestamp = format_timestamp
        prefix = colorize("[BrainzLab]", :bold, :blue)
        arrow = direction == :out ? colorize("->", :cyan) : colorize("<-", :green)
        service_name = colorize(service.to_s.capitalize, :magenta)

        "#{prefix} #{timestamp} #{arrow} #{service_name} #{message}"
      end

      def format_timestamp
        time = Time.now.strftime('%H:%M:%S')
        colorize(time, :dim)
      end

      def format_level(level)
        label = LEVEL_LABELS[level] || level.to_s.upcase
        color = LEVEL_COLORS[level] || :white
        colorize("[#{label}]", color)
      end

      def format_duration(ms)
        if ms < 1
          colorize("#{(ms * 1000).round(0)}us", :green)
        elsif ms < 100
          colorize("#{ms.round(1)}ms", :green)
        elsif ms < 1000
          colorize("#{ms.round(0)}ms", :yellow)
        else
          colorize("#{(ms / 1000.0).round(2)}s", :red)
        end
      end

      def format_data(data)
        pairs = data.map { |k, v| "#{k}: #{format_value(v)}" }
        colorize("(#{pairs.join(', ')})", :dim)
      end

      def format_data_inline(data)
        data.map { |k, v| "#{k}: #{format_value(v)}" }.join(', ')
      end

      def format_value(value)
        case value
        when String
          value.length > 50 ? "#{value[0..47]}..." : value
        when Hash
          "{#{value.keys.join(', ')}}"
        when Array
          "[#{value.length} items]"
        else
          value.to_s
        end
      end

      def summarize_data(data)
        return nil unless data.is_a?(Hash)

        summary_parts = []
        summary_parts << "\"#{truncate(data[:message] || data['message'], 30)}\"" if data[:message] || data['message']

        other_keys = data.keys.reject { |k| %i[message timestamp level].include?(k.to_sym) }
        if other_keys.any?
          key_summary = other_keys.take(3).map { |k| "#{k}: #{format_value(data[k])}" }.join(', ')
          key_summary += ", ..." if other_keys.length > 3
          summary_parts << "(#{key_summary})"
        end

        summary_parts.join(' ')
      end

      def truncate(str, length)
        return '' unless str

        str = str.to_s
        str.length > length ? "#{str[0..length - 4]}..." : str
      end

      def status_message(status)
        case status
        when 200 then 'OK'
        when 201 then 'Created'
        when 204 then 'No Content'
        when 400 then 'Bad Request'
        when 401 then 'Unauthorized'
        when 403 then 'Forbidden'
        when 404 then 'Not Found'
        when 422 then 'Unprocessable Entity'
        when 429 then 'Too Many Requests'
        when 500 then 'Internal Server Error'
        when 502 then 'Bad Gateway'
        when 503 then 'Service Unavailable'
        else ''
        end
      end

      def colorize(text, *colors)
        return text unless colorize?

        color_codes = colors.map { |c| COLORS[c] }.compact.join
        "#{color_codes}#{text}#{COLORS[:reset]}"
      end

      def write_output(output, level:)
        config = BrainzLab.configuration

        if config.logger
          case level
          when :debug then config.logger.debug(strip_colors(output))
          when :info then config.logger.info(strip_colors(output))
          when :warn then config.logger.warn(strip_colors(output))
          when :error, :fatal then config.logger.error(strip_colors(output))
          else config.logger.info(strip_colors(output))
          end
        else
          $stderr.puts output
        end
      end

      def strip_colors(text)
        text.gsub(/\e\[\d+m/, '')
      end
    end
  end
end
