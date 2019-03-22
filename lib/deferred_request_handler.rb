require_relative 'deferred_request'
require_relative 'sqs_client'
require_relative 'errors'

class DeferredRequestHandler
  def sqs_client
    @sqs_client = SqsClient.new if @sqs_client.nil?
    @sqs_client
  end

  # Handle storage of proxied requests
  def handle (event)
    begin
      path = event["path"]
      method = event["httpMethod"].downcase

      if ! ['post', 'put', 'patch', 'delete'].include? method
        raise RequestError.new "Invalid request method; Only POST, PUT, PATCH, DELETE supported"
      end
      if ! /\/api\/v0.1\//.match? path
        raise RequestError.new "Invalid request path; Only paths that begin /api/v0.1/ supported"
      end

      request = DeferredRequest.for_event event
      result = sqs_client.write request
      
      respond 200, { success: true, result: result.to_h }

    rescue RequestError => e
      respond 400, message: "RequestError: #{e.message}"

    rescue => e
      Application.logger.error("Error: #{e}")
      respond 500, message: e.message
    end
  end

  def respond(statusCode = 200, body = nil)
    Application.logger.debug("Responding with #{statusCode}", body)
    { statusCode: statusCode, body: body.to_json, headers: { "Content-Type": "application/json" } }
  end
end
