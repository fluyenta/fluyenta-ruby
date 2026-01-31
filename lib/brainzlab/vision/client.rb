# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module BrainzLab
  module Vision
    class Client
      def initialize(config)
        @config = config
      end

      # Execute an autonomous AI task
      def execute_task(instruction:, start_url:, model: nil, browser_provider: nil, max_steps: 50, timeout: 300)
        payload = {
          instruction: instruction,
          start_url: start_url,
          max_steps: max_steps,
          timeout: timeout
        }
        payload[:model] = model if model
        payload[:browser_provider] = browser_provider if browser_provider

        post('/mcp/tools/vision_task', payload)
      end

      # Create a browser session
      def create_session(url: nil, viewport: nil, browser_provider: nil)
        payload = {}
        payload[:url] = url if url
        payload[:viewport] = viewport if viewport
        payload[:browser_provider] = browser_provider if browser_provider

        post('/mcp/tools/vision_session_create', payload)
      end

      # Perform an AI-powered action
      def ai_action(session_id:, instruction:, model: nil)
        payload = {
          session_id: session_id,
          instruction: instruction
        }
        payload[:model] = model if model

        post('/mcp/tools/vision_ai_action', payload)
      end

      # Perform a direct browser action
      def perform(session_id:, action:, selector: nil, value: nil)
        payload = {
          session_id: session_id,
          action: action.to_s
        }
        payload[:selector] = selector if selector
        payload[:value] = value if value

        post('/mcp/tools/vision_perform', payload)
      end

      # Extract structured data
      def extract(session_id:, schema:, instruction: nil)
        payload = {
          session_id: session_id,
          schema: schema
        }
        payload[:instruction] = instruction if instruction

        post('/mcp/tools/vision_extract', payload)
      end

      # Close a session
      def close_session(session_id:)
        post('/mcp/tools/vision_session_close', { session_id: session_id })
      end

      # Take a screenshot
      def screenshot(session_id:, full_page: true)
        post('/mcp/tools/vision_screenshot', {
               session_id: session_id,
               full_page: full_page
             })
      end

      private

      def post(path, payload)
        uri = URI.parse("#{@config.vision_url}#{path}")
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{auth_key}"
        request['User-Agent'] = "brainzlab-sdk-ruby/#{BrainzLab::VERSION}"
        request.body = JSON.generate(payload)

        response = execute(uri, request)

        case response
        when Net::HTTPSuccess
          JSON.parse(response.body, symbolize_names: true)
        when Net::HTTPUnauthorized
          structured_error = AuthenticationError.new(
            'Invalid API key',
            hint: 'Verify your Vision API key is correct and has not expired.',
            code: 'vision_unauthorized'
          )
          log_error(path, structured_error)
          { error: structured_error.message, brainzlab_error: structured_error }
        when Net::HTTPForbidden
          structured_error = AuthenticationError.new(
            'Vision is not enabled for this project',
            hint: 'Enable Vision in your project settings or check your permissions.',
            code: 'vision_forbidden'
          )
          log_error(path, structured_error)
          { error: structured_error.message, brainzlab_error: structured_error }
        when Net::HTTPNotFound
          structured_error = NotFoundError.new(
            "Vision endpoint not found: #{path}",
            hint: 'Verify the Vision service is properly configured.',
            code: 'vision_not_found',
            resource_type: 'endpoint',
            resource_id: path
          )
          log_error(path, structured_error)
          { error: structured_error.message, brainzlab_error: structured_error }
        when Net::HTTPTooManyRequests
          structured_error = RateLimitError.new(
            'Vision rate limit exceeded',
            retry_after: response['Retry-After']&.to_i,
            code: 'vision_rate_limit'
          )
          log_error(path, structured_error)
          { error: structured_error.message, brainzlab_error: structured_error }
        else
          structured_error = ErrorHandler.from_response(response, service: 'Vision', operation: path)
          log_error(path, structured_error)
          { error: structured_error.message, brainzlab_error: structured_error }
        end
      rescue JSON::ParserError => e
        structured_error = ServerError.new(
          "Invalid JSON response from Vision: #{e.message}",
          hint: 'The Vision service returned an unexpected response format.',
          code: 'vision_invalid_response'
        )
        log_error(path, structured_error)
        { error: structured_error.message, brainzlab_error: structured_error }
      rescue StandardError => e
        structured_error = ErrorHandler.wrap(e, service: 'Vision', operation: path)
        log_error(path, structured_error)
        { error: structured_error.message, brainzlab_error: structured_error }
      end

      def log_error(operation, error)
        BrainzLab.debug_log("[Vision::Client] #{operation} failed: #{error.message}")

        # Call on_error callback if configured
        if @config.on_error
          @config.on_error.call(error, { service: 'Vision', operation: operation })
        end
      end

      def auth_key
        @config.vision_ingest_key || @config.vision_api_key || @config.secret_key
      end

      def execute(uri, request)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 10
        http.read_timeout = 300 # Long timeout for AI tasks
        http.request(request)
      end
    end
  end
end
