module EvoFlow
  # Raised on any non-2xx evo-flow response, an unparseable body, or a network
  # failure. Mirrors Crm::Hubspot::Api::BaseClient::ApiError (code + response).
  class HTTPError < StandardError
    attr_reader :code, :response

    def initialize(message = nil, code = nil, response = nil)
      @code = code
      @response = response
      super(message)
    end
  end

  # Raised at construction time for an unusable configuration (missing key, or
  # cleartext transport in production). Fails fast instead of emitting a
  # request that is guaranteed to 401 or that leaks the shared key in cleartext.
  class ConfigurationError < StandardError; end

  # Instance-based (DI-friendly) authenticated HTTP client for evo-flow.
  # Pattern mirrors app/services/crm/hubspot/api/base_client.rb (HTTParty +
  # custom error + handle_response).
  class Client
    include HTTParty

    DEFAULT_API_URL = 'http://evo-flow:3000/api/v1'.freeze
    REDACTED_BODY = '[redacted: auth failure]'.freeze
    MAX_LOGGED_BODY = 500

    def initialize(api_url: ENV.fetch('EVO_FLOW_API_URL', DEFAULT_API_URL),
                   api_key: ENV.fetch('AUTH_APIKEY_INTEGRATION_LOCAL', nil),
                   timeout: 10)
      @api_url = api_url
      @api_key = api_key
      @timeout = timeout
      validate_config!
    end

    def post(path, payload)
      response = self.class.post(join(@api_url, path),
                                 body: payload.to_json,
                                 headers: request_headers,
                                 timeout: @timeout)
      handle_response(response)
    rescue HTTParty::Error, SocketError, Timeout::Error, SystemCallError => e
      raise EvoFlow::HTTPError.new("evo-flow request failed: #{e.message}", nil, nil)
    end

    private

    def validate_config!
      raise ConfigurationError, 'AUTH_APIKEY_INTEGRATION_LOCAL is not set' if @api_key.to_s.strip.empty?
      return if URI(@api_url).scheme == 'https'
      return unless Rails.env.production?
      return if ENV.fetch('EVO_FLOW_ALLOW_INSECURE', nil) == 'true'

      raise ConfigurationError,
            "refusing to send the API key over cleartext (#{@api_url}); use https " \
            'or set EVO_FLOW_ALLOW_INSECURE=true only on a trusted private network'
    end

    # URI.join drops the /api/v1 prefix when path starts with '/' (a leading
    # slash resets to root). A *relative* join (base ends with '/', path has
    # no leading slash) preserves the prefix and normalises the boundary.
    def join(base, path)
      URI.join("#{base.chomp('/')}/", path.to_s.sub(%r{\A/+}, '')).to_s
    end

    def request_headers
      { 'Content-Type' => 'application/json', 'X-Integration-API-Key' => @api_key }
    end

    def handle_response(response)
      raise_api_error(response) unless (200..299).cover?(response.code)

      parse_body(response)
    end

    def parse_body(response)
      response.parsed_response
    rescue JSON::ParserError, TypeError => e
      raise EvoFlow::HTTPError.new("evo-flow returned an unparseable body: #{e.message}",
                                   response.code, response)
    end

    def raise_api_error(response)
      msg = "evo-flow API error: #{response.code} - #{safe_body(response)}"
      Rails.logger.error(msg)
      # error.response still carries the full HTTParty response for programmatic
      # use; only the logged/message form is redacted/bounded.
      raise EvoFlow::HTTPError.new(msg, response.code, response)
    end

    # Auth-rejection bodies frequently echo the offending key/context, so they
    # are never logged. Other bodies are length-bounded to keep logs sane.
    def safe_body(response)
      return REDACTED_BODY if [401, 403].include?(response.code)

      body = response.body.to_s
      body.length > MAX_LOGGED_BODY ? "#{body[0, MAX_LOGGED_BODY]}... (truncated)" : body
    end
  end
end
