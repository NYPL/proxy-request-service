require 'uri'

class DeferredRequest
  attr_accessor :request

  def initialize (request)
    @request = request
  end

  def to_s
    request_uri = @request[:path]
    query_string = URI.encode_www_form(@request[:queryStringParameters]) if @request[:queryStringParameters]
    request_uri += "?#{query_string}" if query_string
    "#{@request[:httpMethod]} #{request_uri} (body: #{@request[:body]})"
  end

  def self.for_event (event)
    # Strip 'Authorization' header if given
    cleaned_headers = self.strip_key_from_json event['headers'], 'Authorization'
    
    request = {
      httpMethod: event['httpMethod'],
      path: event['path'],
      body: event['body'],
      isBase64Encoded: event['isBase64Encoded'],
      headers: cleaned_headers,
      queryStringParameters: event['queryStringParameters']
    }

    self.new(request)
  end

  # Given a (string) json value, returns a (string) json with the named key-
  # value removed
  def self.strip_key_from_json (json, key)
    cleaned = {}
    if json
      cleaned = JSON.parse(json).inject({}) do |h, (k, v)|
        h[k] = v unless k == key
        h
      end
    end
    cleaned.to_json
  end
end
