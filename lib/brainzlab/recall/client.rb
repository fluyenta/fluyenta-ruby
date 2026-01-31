# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module BrainzLab
  module Recall
    class Client
      MAX_RETRIES = 3
      RETRY_DELAY = 0.5

      def initialize(config)
        @config = config
        @uri = URI.parse(config.recall_url)
      end

      def send_log(log_entry)
        return unless @config.recall_enabled && @config.valid?

        post('/api/v1/log', log_entry)
      end

      def send_batch(log_entries)
        return unless @config.recall_enabled && @config.valid?
        return if log_entries.empty?

        post('/api/v1/logs', { logs: log_entries })
      end

      private

      def post(path, body)
        uri = URI.join(@config.recall_url, path)

        # Call on_send callback if configured
        invoke_on_send(:recall, :post, path, body)

        # Log debug output for request
        log_debug_request(path, body)

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{@config.secret_key}"
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
              StandardError.new("Recall API error: #{response.code}"),
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

        data = if body.is_a?(Hash) && body[:logs]
                 { count: body[:logs].size }
               elsif body.is_a?(Hash) && body[:message]
                 { message: body[:message] }
               else
                 {}
               end

        BrainzLab::Debug.log_request(:recall, 'POST', path, data: data)
      end

      def log_debug_response(status, duration_ms, error: nil)
        return unless BrainzLab::Debug.enabled?

        BrainzLab::Debug.log_response(:recall, status, duration_ms, error: error)
      end

      def invoke_on_send(service, method, path, payload)
        return unless @config.on_send

        @config.on_send.call(service, method, path, payload)
      rescue StandardError => e
        # Don't let callback errors break the SDK
        log_error("on_send callback error: #{e.message}")
      end

      def handle_error(error, context: {})
        # Wrap the error in a structured error if it's not already one
        structured_error = if error.is_a?(BrainzLab::Error)
                             error
                           else
                             ErrorHandler.wrap(error, service: 'Recall', operation: context[:path] || 'unknown')
                           end

        log_error(structured_error.message)

        # Call on_error callback if configured
        return unless @config.on_error

        @config.on_error.call(structured_error, context.merge(service: :recall))
      rescue StandardError => e
        # Don't let callback errors break the SDK
        log_error("on_error callback error: #{e.message}")
      end

      def log_error(message)
        BrainzLab::Debug.log(message, level: :error) if BrainzLab::Debug.enabled?

        return unless @config.logger

        @config.logger.error("[BrainzLab::Recall] #{message}")
      end

      class RetryableError < StandardError; end
    end
  end
end
