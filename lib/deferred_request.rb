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
    cleaned_headers = self.strip_key_from_hash event['headers'], :'Authorization'
    
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

  # Given a hash, returns a copy of hash with specified key removed
  def self.strip_key_from_hash (h, key)
    h.delete key if h
    h
  end
end
