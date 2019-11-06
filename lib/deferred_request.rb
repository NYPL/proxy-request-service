require 'uri'

require_relative './job_client'

class DeferredRequest
  attr_accessor :request, :job_id

  def initialize (request, job_id = nil)
    @request = request
    @job_id = job_id
  end

  def id
    # If we got a requestId, use that as it's presumed globally unique
    # TODO This is used to identify distinct requests to preserve ordering in
    # the FIFO queue. Is there a situation where requestContext.requestId would
    # *not* be set, leading to a nil id, leading to chaos?
    @request[:requestId]
  end

  def to_s
    request_uri = @request[:path]
    query_string = URI.encode_www_form(@request[:queryStringParameters]) if @request[:queryStringParameters]
    request_uri += "?#{query_string}" if query_string
    "#{@request[:httpMethod]} #{request_uri} (body: #{@request[:body]})"
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

    job_id = nil
    # Determine whether or not to generate a jobId
    if self.should_create_job? request
      job_id = JobClient::generate_job_id
      request[:body] = add_body_param :jobId, job_id, request

      Application.logger.debug("Added jobid to DeferredRequest: #{request[:body]}")
    end

    # Remove the special override param:
    self.strip_key_from_hash request[:queryStringParameters], 'proxyServiceCreateJob'

    self.new(request, job_id)
  end

  # Returns true if we should generate a job id for the given request
  def self.should_create_job? (request)
    # By default, we should generate a jobId
    # Skip generating a jobId only if query param `proxyServiceCreateJob` != 'true'
    if request[:queryStringParameters] && request[:queryStringParameters]['proxyServiceCreateJob']
      request[:queryStringParameters]['proxyServiceCreateJob'] == 'true'
    else
      true
    end
  end

  # Add given key-value to given request's :body.
  # Assumes body is stringified (possibly base64 encoded) json
  def self.add_body_param (key, value, request)
    body = request[:body]
    body = Base64.decode64 body if request[:isBase64Encoded]

    if body
      begin
        body = JSON.parse body
      rescue StandardError => e
        raise "Failed to parse JSON from #{request[:isBase64Encoded] ? '' : 'non-'}base64-encoded request body: #{request[:body]}"
      end
    else
      body = {}
    end

    body[key] = value

    body = body.to_json
    body = Base64.encode64 body if request[:isBase64Encoded]
    body
  end

  # Given a hash, returns a copy of hash with specified key removed
  def self.strip_key_from_hash (h, key)
    h.delete key if h
    h
  end
end
