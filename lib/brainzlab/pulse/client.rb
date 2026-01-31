# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module BrainzLab
  module Pulse
    class Client
      MAX_RETRIES = 3
      RETRY_DELAY = 0.5

      def initialize(config)
        @config = config
        @buffer = []
        @mutex = Mutex.new
        @flush_thread = nil
      end

      def send_trace(payload)
        return unless @config.pulse_enabled && @config.pulse_valid?

        if @config.pulse_buffer_size > 1
          buffer_trace(payload)
        else
          post('/api/v1/traces', payload)
        end
      end

      def send_batch(payloads)
        return unless @config.pulse_enabled && @config.pulse_valid?
        return if payloads.empty?

        post('/api/v1/traces/batch', { traces: payloads })
      end

      def send_metric(payload)
        return unless @config.pulse_enabled && @config.pulse_valid?

        post('/api/v1/metrics', payload)
      end

      def send_span(payload)
        return unless @config.pulse_enabled && @config.pulse_valid?

        post('/api/v1/spans', payload)
      end

      def flush
        traces_to_send = nil

        @mutex.synchronize do
          return if @buffer.empty?

          traces_to_send = @buffer.dup
          @buffer.clear
        end

        send_batch(traces_to_send) if traces_to_send&.any?
      end

      private

      def buffer_trace(payload)
        should_flush = false

        @mutex.synchronize do
          @buffer << payload
          should_flush = @buffer.size >= @config.pulse_buffer_size
        end

        start_flush_timer unless @flush_thread&.alive?
        flush if should_flush
      end

      def start_flush_timer
        @flush_thread = Thread.new do
          loop do
            sleep(@config.pulse_flush_interval)
            flush
          end
        end
      end

      def post(path, body)
        uri = URI.join(@config.pulse_url, path)

        # Call on_send callback if configured
        invoke_on_send(:pulse, :post, path, body)

        # Log debug output for request
        log_debug_request(path, body)

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{@config.pulse_auth_key}"
        request['User-Agent'] = "brainzlab-sdk-ruby/#{BrainzLab::VERSION}"
        request.body = JSON.generate(body)

        execute_with_retry(uri, request, path)
      rescue StandardError => e
        handle_error(e, context: { path: path, body_size: body.to_s.length })
        nil
      end

      def execute_with_retry(uri, request, path)
        retries = 0
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.open_timeout = 5
          http.read_timeout = 10

          response = http.request(request)
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

          # Log debug output for response
          log_debug_response(response.code.to_i, duration_ms)

          case response.code.to_i
          when 200..299
            begin
              JSON.parse(response.body)
            rescue StandardError
              {}
            end
          when 429, 500..599
            raise RetryableError, "Server error: #{response.code}"
          else
            handle_error(
              StandardError.new("Pulse API error: #{response.code}"),
              context: { path: path, status: response.code, body: response.body }
            )
            nil
          end
        rescue RetryableError, Net::OpenTimeout, Net::ReadTimeout => e
          retries += 1
          if retries <= MAX_RETRIES
            sleep(RETRY_DELAY * retries)
            retry
          end
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          log_debug_response(0, duration_ms, error: e.message)
          handle_error(e, context: { path: path, retries: retries })
          nil
        end
      end

      def log_debug_request(path, body)
        return unless BrainzLab::Debug.enabled?

        data = if body.is_a?(Hash) && body[:traces]
                 { count: body[:traces].size }
               elsif body.is_a?(Hash) && body[:name]
                 { name: body[:name] }
               else
                 {}
               end

        BrainzLab::Debug.log_request(:pulse, 'POST', path, data: data)
      end

      def log_debug_response(status, duration_ms, error: nil)
        return unless BrainzLab::Debug.enabled?

        BrainzLab::Debug.log_response(:pulse, status, duration_ms, error: error)
      end

      def invoke_on_send(service, method, path, payload)
        return unless @config.on_send

        @config.on_send.call(service, method, path, payload)
      rescue StandardError => e
        # Don't let callback errors break the SDK
        log_error("on_send callback error: #{e.message}")
      end

      def handle_error(error, context: {})
        log_error("#{error.message}")

        # Call on_error callback if configured
        return unless @config.on_error

        @config.on_error.call(error, context.merge(service: :pulse))
      rescue StandardError => e
        # Don't let callback errors break the SDK
        log_error("on_error callback error: #{e.message}")
      end

      def log_error(message)
        BrainzLab::Debug.log(message, level: :error) if BrainzLab::Debug.enabled?

        return unless @config.logger

        @config.logger.error("[BrainzLab::Pulse] #{message}")
      end

      class RetryableError < StandardError; end
    end
  end
end
