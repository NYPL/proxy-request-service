require 'nypl_log_formatter'

require_relative File.join('lib', 'deferred_request_handler')

Application = OpenStruct.new

Application.logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

Application.handlers = {
  deferred_request: DeferredRequestHandler.new
}

# Main handler:
def handle_event(event:, context:)
  # Dispatch event to relevant handler (in this case only one):
  Application.handlers[:deferred_request].handle event
end
