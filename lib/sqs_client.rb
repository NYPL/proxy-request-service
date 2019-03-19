require 'aws-sdk-sqs'

require_relative './kms_client'

class SqsClient
  def initialize
    @sqs_queue_url = KmsClient.new.decrypt ENV['SQS_QUEUE_URL']

    # Strip rogue whitespace from encrypted value:
    @sqs_queue_url.strip!

    # Extract SQS endpoint (protocol + FQDN) from URL:
    @sqs_queue_endpoint = @sqs_queue_url.match(/https?:\/\/[^\/]+/)[0]
    # Extract SQS queue name from URL:
    @sqs_queue_name = @sqs_queue_url.match(/[\w-]+$/)[0]

    @sqs = Aws::SQS::Client.new(
      region: 'us-east-1',
      endpoint: @sqs_queue_endpoint
    )   
  end 

  def write (sqs_entry)
    begin
      $logger.debug "Writing deferred request to SQS: #{sqs_entry}"
      @sqs.send_message({
        queue_url: @sqs_queue_url,
        message_body: JSON.generate(sqs_entry.request)
      })
    rescue Exception => e
      $logger.error "SqsClient error: #{e.message}"
      raise e
    end
  end
end
