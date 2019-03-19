require 'base64'
require 'nypl_log_formatter'

require_relative 'lib/sqs_client'
require_relative 'lib/errors'
require_relative 'lib/deferred_request'

def init
  return if $initialized

  $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

  $sqs_client = SqsClient.new

  $initialized = true
end

# Main handler:
def handle_event(event:, context:)
  init

  return handle_proxy_request event
end

# Handle storage of proxied requests
def handle_proxy_request (event)
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
    result = $sqs_client.write request
    
    respond 200, { success: true, result: result.to_h }

  rescue RequestError => e
    respond 400, message: "RequestError: #{e.message}"

  rescue => e
    respond 500, message: e.message
  end
end

def respond(statusCode = 200, body = nil)
  $logger.debug("Responding with #{statusCode}", body)
  { statusCode: statusCode, body: body.to_json, headers: { "Content-Type": "application/json" } }
end
