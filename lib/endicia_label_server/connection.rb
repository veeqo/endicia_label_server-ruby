require 'uri'
require 'excon'
require 'digest/md5'
require 'ox'

module EndiciaLabelServer
  # The {Connection} class acts as the main entry point to performing rate and
  # ship operations against the Endicia API.
  #
  # @author Paul Trippett
  # @abstract
  # @since 0.1.0
  # @attr [String] url The base url to use either TEST_URL or LIVE_URL
  class Connection
    include EndiciaLabelServer::Builders
    include EndiciaLabelServer::Parsers

    attr_accessor :url

    TEST_URL = 'https://LabelServer.Endicia.com'
    LIVE_URL = 'https://LabelServer.Endicia.com'
    ROOT_PATH = '/LabelService/EwsLabelService.asmx/'

    GET_POSTAGE_LABEL_ENDPOINT = 'GetPostageLabelXML'
    REQUEST_RATE_ENDPOINT = 'CalculatePostageRateXML'
    REQUEST_RATES_ENDPOINT = 'CalculatePostageRatesXML'

    DEFAULT_PARAMS = {
      test_mode: false
    }

    HEADERS = {
      'Content-Type' => 'application/x-www-form-urlencoded'
    }

    # Initializes a new {Connection} object
    #
    # @param [Hash] params The initialization options
    # @option params [Boolean] :test_mode If TEST_URL should be used for
    #   requests to the Endicia Label Server URL
    def initialize(params = {})
      params = DEFAULT_PARAMS.merge(params)
      self.url = (params[:test_mode]) ? TEST_URL : LIVE_URL
    end

    def rate(builder = nil)
      builder_proxy(builder, REQUEST_RATE_ENDPOINT, PostageRateBuilder,
                    PostageRateParser, &Proc.new)
    end

    def rates(builder = nil)
      builder_proxy(builder, REQUEST_RATES_ENDPOINT, PostageRatesBuilder,
                    PostageRatesParser, &Proc.new)
    end

    private

    def build_url(endpoint)
      "#{url}#{ROOT_PATH}#{endpoint}"
    end

    def get_response_stream(path, body)
      response = Excon.post(build_url(path), body: body, headers: HEADERS)
      StringIO.new(response.body)
    end

    def builder_proxy(builder, path, builder_type, parser)
      if builder.nil? && block_given?
        builder = builder_type.new
        yield builder
      end

      response = get_response_stream path, builder.to_http_post
      parser.new.tap do |p|
        Ox.sax_parse(p, response)
      end
    end
  end
end
