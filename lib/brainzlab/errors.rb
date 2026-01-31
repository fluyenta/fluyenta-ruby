# frozen_string_literal: true

module BrainzLab
  # Base error class for all BrainzLab SDK errors.
  # Provides structured error information including hints and documentation links.
  #
  # @example Raising a structured error
  #   raise BrainzLab::Error.new(
  #     "Operation failed",
  #     hint: "Check your network connection",
  #     docs_url: "https://docs.brainzlab.io/troubleshooting",
  #     code: "operation_failed"
  #   )
  #
  # @example Catching and inspecting errors
  #   begin
  #     BrainzLab::Vault.get("secret")
  #   rescue BrainzLab::Error => e
  #     puts e.message    # What went wrong
  #     puts e.hint       # How to fix it
  #     puts e.docs_url   # Where to learn more
  #     puts e.code       # Machine-readable code
  #   end
  #
  class Error < StandardError
    # @return [String, nil] A helpful hint on how to resolve the error
    attr_reader :hint

    # @return [String, nil] URL to relevant documentation
    attr_reader :docs_url

    # @return [String, nil] Machine-readable error code for programmatic handling
    attr_reader :code

    # @return [Hash, nil] Additional context about the error
    attr_reader :context

    DOCS_BASE_URL = 'https://docs.brainzlab.io'

    # Initialize a new BrainzLab error.
    #
    # @param message [String] The error message describing what went wrong
    # @param hint [String, nil] A helpful hint on how to resolve the error
    # @param docs_url [String, nil] URL to relevant documentation
    # @param code [String, nil] Machine-readable error code
    # @param context [Hash, nil] Additional context about the error
    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil)
      @message = message
      @hint = hint
      @docs_url = docs_url
      @code = code
      @context = context
      super(message)
    end

    # Format the error as a detailed string with hints and documentation links.
    #
    # @return [String] Formatted error message
    def to_s
      super
    end

    # Return a detailed formatted version of the error with hints and documentation links.
    # Use this method when you want the full structured output.
    #
    # @return [String] Detailed formatted error message
    def detailed_message(highlight: false, **_kwargs)
      # Get the base message without class name duplication
      base_msg = @message || super

      parts = ["#{self.class.name}: #{base_msg}"]

      parts << "" << "Hint: #{hint}" if hint
      parts << "Docs: #{docs_url}" if docs_url
      parts << "Code: #{code}" if code

      if context && !context.empty?
        parts << "" << "Context:"
        context.each do |key, value|
          parts << "  #{key}: #{value}"
        end
      end

      parts.join("\n")
    end

    # Inspect the error for debugging
    #
    # @return [String] Inspection output
    def inspect
      "#<#{self.class.name}: #{message}#{" (#{code})" if code}>"
    end

    # Return a hash representation of the error for logging/serialization.
    #
    # @return [Hash] Error details as a hash
    def to_h
      {
        error_class: self.class.name,
        message: message,
        hint: hint,
        docs_url: docs_url,
        code: code,
        context: context
      }.compact
    end

    # Alias for to_h
    def as_json
      to_h
    end
  end

  # Raised when the SDK is misconfigured or required configuration is missing.
  #
  # @example Missing API key
  #   raise BrainzLab::ConfigurationError.new(
  #     "API key is required",
  #     hint: "Set BRAINZLAB_SECRET_KEY environment variable or configure via BrainzLab.configure",
  #     code: "missing_api_key"
  #   )
  #
  class ConfigurationError < Error
    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil)
      docs_url ||= "#{DOCS_BASE_URL}/sdk/ruby/configuration"
      code ||= 'configuration_error'
      super(message, hint: hint, docs_url: docs_url, code: code, context: context)
    end
  end

  # Raised when authentication fails due to invalid or expired credentials.
  #
  # @example Invalid API key
  #   raise BrainzLab::AuthenticationError.new(
  #     "Invalid API key",
  #     hint: "Check that your API key is correct and has not expired",
  #     code: "invalid_api_key"
  #   )
  #
  class AuthenticationError < Error
    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil)
      docs_url ||= "#{DOCS_BASE_URL}/sdk/ruby/authentication"
      code ||= 'authentication_error'
      super(message, hint: hint, docs_url: docs_url, code: code, context: context)
    end
  end

  # Raised when a connection to BrainzLab services cannot be established.
  #
  # @example Connection timeout
  #   raise BrainzLab::ConnectionError.new(
  #     "Connection timed out",
  #     hint: "Check your network connection and firewall settings",
  #     code: "connection_timeout"
  #   )
  #
  class ConnectionError < Error
    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil)
      docs_url ||= "#{DOCS_BASE_URL}/sdk/ruby/troubleshooting#connection-issues"
      code ||= 'connection_error'
      super(message, hint: hint, docs_url: docs_url, code: code, context: context)
    end
  end

  # Raised when the rate limit for API requests has been exceeded.
  #
  # @example Rate limit exceeded
  #   raise BrainzLab::RateLimitError.new(
  #     "Rate limit exceeded",
  #     hint: "Wait before retrying or consider upgrading your plan",
  #     code: "rate_limit_exceeded",
  #     context: { retry_after: 60, limit: 1000, remaining: 0 }
  #   )
  #
  class RateLimitError < Error
    # @return [Integer, nil] Seconds to wait before retrying
    attr_reader :retry_after

    # @return [Integer, nil] The rate limit ceiling
    attr_reader :limit

    # @return [Integer, nil] Remaining requests in the current window
    attr_reader :remaining

    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil, retry_after: nil, limit: nil, remaining: nil)
      @retry_after = retry_after
      @limit = limit
      @remaining = remaining

      hint ||= retry_after ? "Wait #{retry_after} seconds before retrying" : 'Reduce request frequency or upgrade your plan'
      docs_url ||= "#{DOCS_BASE_URL}/sdk/ruby/rate-limits"
      code ||= 'rate_limit_exceeded'

      context ||= {}
      context[:retry_after] = retry_after if retry_after
      context[:limit] = limit if limit
      context[:remaining] = remaining if remaining

      super(message, hint: hint, docs_url: docs_url, code: code, context: context.empty? ? nil : context)
    end
  end

  # Raised when request parameters or data fail validation.
  #
  # @example Invalid parameter
  #   raise BrainzLab::ValidationError.new(
  #     "Invalid email format",
  #     hint: "Provide a valid email address (e.g., user@example.com)",
  #     code: "invalid_email",
  #     context: { field: "email", value: "invalid" }
  #   )
  #
  class ValidationError < Error
    # @return [String, nil] The field that failed validation
    attr_reader :field

    # @return [Array<Hash>, nil] List of validation errors for multiple fields
    attr_reader :errors

    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil, field: nil, errors: nil)
      @field = field
      @errors = errors

      docs_url ||= "#{DOCS_BASE_URL}/sdk/ruby/api-reference"
      code ||= 'validation_error'

      context ||= {}
      context[:field] = field if field
      context[:errors] = errors if errors

      super(message, hint: hint, docs_url: docs_url, code: code, context: context.empty? ? nil : context)
    end
  end

  # Raised when a requested resource is not found.
  #
  # @example Resource not found
  #   raise BrainzLab::NotFoundError.new(
  #     "Secret 'database_url' not found",
  #     hint: "Verify the secret name and environment",
  #     code: "secret_not_found"
  #   )
  #
  class NotFoundError < Error
    # @return [String, nil] The type of resource that was not found
    attr_reader :resource_type

    # @return [String, nil] The identifier of the resource that was not found
    attr_reader :resource_id

    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil, resource_type: nil, resource_id: nil)
      @resource_type = resource_type
      @resource_id = resource_id

      code ||= 'not_found'

      context ||= {}
      context[:resource_type] = resource_type if resource_type
      context[:resource_id] = resource_id if resource_id

      super(message, hint: hint, docs_url: docs_url, code: code, context: context.empty? ? nil : context)
    end
  end

  # Raised when a server-side error occurs.
  #
  # @example Server error
  #   raise BrainzLab::ServerError.new(
  #     "Internal server error",
  #     hint: "This is a temporary issue. Please retry your request.",
  #     code: "internal_server_error"
  #   )
  #
  class ServerError < Error
    # @return [Integer, nil] HTTP status code from the server
    attr_reader :status_code

    # @return [String, nil] Request ID for support reference
    attr_reader :request_id

    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil, status_code: nil, request_id: nil)
      @status_code = status_code
      @request_id = request_id

      hint ||= 'This is a temporary issue. Please retry your request. If the problem persists, contact support.'
      docs_url ||= "#{DOCS_BASE_URL}/sdk/ruby/troubleshooting#server-errors"
      code ||= 'server_error'

      context ||= {}
      context[:status_code] = status_code if status_code
      context[:request_id] = request_id if request_id

      super(message, hint: hint, docs_url: docs_url, code: code, context: context.empty? ? nil : context)
    end
  end

  # Raised when an operation times out.
  #
  # @example Request timeout
  #   raise BrainzLab::TimeoutError.new(
  #     "Request timed out after 30 seconds",
  #     hint: "The operation took too long. Try again or increase timeout settings.",
  #     code: "request_timeout"
  #   )
  #
  class TimeoutError < Error
    # @return [Integer, nil] Timeout duration in seconds
    attr_reader :timeout_seconds

    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil, timeout_seconds: nil)
      @timeout_seconds = timeout_seconds

      hint ||= 'The operation took too long. Try again or increase timeout settings.'
      docs_url ||= "#{DOCS_BASE_URL}/sdk/ruby/configuration#timeouts"
      code ||= 'timeout'

      context ||= {}
      context[:timeout_seconds] = timeout_seconds if timeout_seconds

      super(message, hint: hint, docs_url: docs_url, code: code, context: context.empty? ? nil : context)
    end
  end

  # Raised when a service is temporarily unavailable.
  #
  # @example Service unavailable
  #   raise BrainzLab::ServiceUnavailableError.new(
  #     "Vault service is currently unavailable",
  #     hint: "The service is undergoing maintenance. Please try again later.",
  #     code: "vault_unavailable"
  #   )
  #
  class ServiceUnavailableError < Error
    # @return [String, nil] The name of the unavailable service
    attr_reader :service_name

    def initialize(message = nil, hint: nil, docs_url: nil, code: nil, context: nil, service_name: nil)
      @service_name = service_name

      hint ||= 'The service is temporarily unavailable. Please try again later.'
      docs_url ||= "#{DOCS_BASE_URL}/status"
      code ||= 'service_unavailable'

      context ||= {}
      context[:service_name] = service_name if service_name

      super(message, hint: hint, docs_url: docs_url, code: code, context: context.empty? ? nil : context)
    end
  end

  # Helper module for wrapping low-level errors into structured BrainzLab errors
  module ErrorHandler
    module_function

    # Wrap a standard error into a structured BrainzLab error.
    #
    # @param error [StandardError] The original error
    # @param service [String] The service name (e.g., 'Vault', 'Cortex')
    # @param operation [String] The operation being performed
    # @return [BrainzLab::Error] A structured BrainzLab error
    def wrap(error, service:, operation:)
      case error
      when Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
        TimeoutError.new(
          "#{service} #{operation} timed out: #{error.message}",
          hint: 'Check your network connection or increase timeout settings.',
          code: "#{service.downcase}_timeout",
          context: { service: service, operation: operation }
        )
      when Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH
        ConnectionError.new(
          "Unable to connect to #{service}: #{error.message}",
          hint: 'Check that the service is running and accessible.',
          code: "#{service.downcase}_connection_failed",
          context: { service: service, operation: operation }
        )
      when SocketError
        ConnectionError.new(
          "DNS resolution failed for #{service}: #{error.message}",
          hint: 'Check your network connection and DNS settings.',
          code: "#{service.downcase}_dns_error",
          context: { service: service, operation: operation }
        )
      when JSON::ParserError
        ServerError.new(
          "Invalid response from #{service}: #{error.message}",
          hint: 'The server returned an unexpected response format.',
          code: "#{service.downcase}_invalid_response",
          context: { service: service, operation: operation }
        )
      when OpenSSL::SSL::SSLError
        ConnectionError.new(
          "SSL error connecting to #{service}: #{error.message}",
          hint: 'Check SSL certificates and ensure the connection is secure.',
          code: "#{service.downcase}_ssl_error",
          context: { service: service, operation: operation }
        )
      else
        Error.new(
          "#{service} #{operation} failed: #{error.message}",
          hint: 'An unexpected error occurred. Check the logs for more details.',
          code: "#{service.downcase}_error",
          context: { service: service, operation: operation, original_error: error.class.name }
        )
      end
    end

    # Convert an HTTP response to a structured error.
    #
    # @param response [Net::HTTPResponse] The HTTP response
    # @param service [String] The service name
    # @param operation [String] The operation being performed
    # @return [BrainzLab::Error] A structured BrainzLab error
    def from_response(response, service:, operation:)
      status_code = response.code.to_i
      body = parse_response_body(response)
      message = body[:message] || body[:error] || "HTTP #{status_code}"
      request_id = response['X-Request-Id']

      case status_code
      when 400
        ValidationError.new(
          message,
          hint: body[:hint] || 'Check the request parameters.',
          code: body[:code] || 'bad_request',
          context: { service: service, operation: operation, status_code: status_code }
        )
      when 401
        AuthenticationError.new(
          message,
          hint: body[:hint] || "Verify your #{service} API key is correct and active.",
          code: body[:code] || 'unauthorized',
          context: { service: service, operation: operation }
        )
      when 403
        AuthenticationError.new(
          message,
          hint: body[:hint] || 'Your API key does not have permission for this operation.',
          code: body[:code] || 'forbidden',
          context: { service: service, operation: operation }
        )
      when 404
        NotFoundError.new(
          message,
          hint: body[:hint] || 'The requested resource does not exist.',
          code: body[:code] || 'not_found',
          context: { service: service, operation: operation }
        )
      when 422
        ValidationError.new(
          message,
          hint: body[:hint] || 'The request was well-formed but contained invalid data.',
          code: body[:code] || 'unprocessable_entity',
          errors: body[:errors],
          context: { service: service, operation: operation, status_code: status_code }
        )
      when 429
        RateLimitError.new(
          message,
          retry_after: response['Retry-After']&.to_i,
          limit: response['X-RateLimit-Limit']&.to_i,
          remaining: response['X-RateLimit-Remaining']&.to_i,
          context: { service: service, operation: operation }
        )
      when 500..599
        ServerError.new(
          message,
          hint: body[:hint] || 'A server error occurred. Please retry your request.',
          code: body[:code] || "server_error_#{status_code}",
          status_code: status_code,
          request_id: request_id,
          context: { service: service, operation: operation }
        )
      else
        Error.new(
          message,
          hint: body[:hint],
          code: body[:code] || "http_#{status_code}",
          context: { service: service, operation: operation, status_code: status_code }
        )
      end
    end

    def parse_response_body(response)
      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError, TypeError
      {}
    end
  end
end
