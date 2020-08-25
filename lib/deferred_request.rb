require 'uri'

require_relative './job_client'

class DeferredRequest
  def initialize (request)
    @original_request = request
    compute_job_id if should_create_job?
  end

  # Get a hash serialization of this instance suitable for placing in SQS
  def serialize
    hash = @original_request

    if hash[:queryStringParameters]
      # Remove the special override param:
      self.class.strip_key_from_hash hash[:queryStringParameters], 'proxyServiceCreateJob'
    end

    hash[:body] = encoded_request_body

    hash
  end

  # Generate a JSON response for the caller
  def response
    @response ||= default_response
  end

  def id
    # If we got a requestId, use that as it's presumed globally unique
    # TODO This is used to identify distinct requests to preserve ordering in
    # the FIFO queue. Is there a situation where requestContext.requestId would
    # *not* be set, leading to a nil id, leading to chaos?
    @original_request[:requestId]
  end

  def to_s
    request_uri = @original_request[:path]
    query_string = URI.encode_www_form(@original_request[:queryStringParameters]) if @original_request[:queryStringParameters]
    request_uri += "?#{query_string}" if query_string
    "#{@original_request[:httpMethod]} #{request_uri} (body: #{@original_request[:body]})"
  end

  private

  # Get request body as a Hash
  def request_body
    @request_body ||= decode_request_body
  end

  # Returns the request body decoded as a JSON hash
  def decode_request_body
    body = @original_request[:body]
    body = Base64.decode64 body if @original_request[:isBase64Encoded]

    if body
      begin
        body = JSON.parse body
      rescue StandardError => e
        raise "Failed to parse JSON from #{request[:isBase64Encoded] ? '' : 'non-'}base64-encoded request body: #{request[:body]}"
      end
    else
      body = {}
    end

    body
  end

  # Returns an encoded request body suitable for queueing
  def encoded_request_body
    # Special case: If 1) original request body was empty and 2) we haven't
    # added anything to the request body, the new request body should be
    # null rather than '{}' to better match the original request:
    return nil if !@original_request[:body] && request_body.keys.empty?

    body = request_body.to_json
    body = Base64.encode64 body if @original_request[:isBase64Encoded]
    body
  end

  # Generate a job_id for this deferred request
  def compute_job_id
    job_id = JobClient::generate_job_id
    request_body[:jobId] = job_id
    response[:data][:jobId] = job_id

    Application.logger.debug("Added jobid to DeferredRequest: #{@original_request[:body]}")
  end

  # Build a default initial response that includes common params that identify
  # the request:
  def default_response
    # Establish what request params should be returned to caller:
    [:itemBarcode].inject({ data: {} }) do |h, prop|
      val = request_body[prop.to_s]
      h[:data][prop] = val if val
      h
    end
  end

  # Returns true if we should generate a job id for the given request
  def should_create_job?
    # By default, we should generate a jobId
    # Skip generating a jobId only if query param `proxyServiceCreateJob` != 'true'
    if @original_request[:queryStringParameters] && @original_request[:queryStringParameters]['proxyServiceCreateJob']
      @original_request[:queryStringParameters]['proxyServiceCreateJob'] == 'true'
    else
      true
    end
  end

  # Generate a DeferredRequest instance for the given event
  def self.for_event (event)
    # Strip 'Authorization' header if given
    cleaned_headers = self.strip_key_from_hash event['headers'], :'Authorization'

    request = {
      httpMethod: event['httpMethod'],
      path: event['path'],
      body: event['body'],
      isBase64Encoded: event['isBase64Encoded'],
      headers: cleaned_headers,
      queryStringParameters: event['queryStringParameters'],
      requestId: event['requestContext'].nil? ? nil : event['requestContext']['requestId']
    }

    self.new(request)
  end

  # Given a hash, returns a copy of hash with specified key removed
  def self.strip_key_from_hash (h, key)
    h.delete key if h
    h
  end
end
