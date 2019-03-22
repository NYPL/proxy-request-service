require 'aws-sdk-sqs'

require_relative 'kms_client'

class SqsClient
  # FIFO order is preserved over a message group; We thus want only one message
  # group.
  # https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/using-messagegroupid-property.html
  MESSAGE_GROUP_ID = 'proxy-requests'

  def initialize
    init_aws_client
  end

  def init_aws_client
    sqs_config = parse_sqs_url KmsClient.new.decrypt ENV['SQS_QUEUE_URL']

    @sqs_queue_url = sqs_config[:queue_url]

    @sqs = Aws::SQS::Client.new(
      region: 'us-east-1',
      endpoint: sqs_config[:endpoint]
    )   
  end

  def parse_sqs_url (queue_url)
    # Strip rogue whitespace from encrypted value:
    queue_url.strip!

    # Extract SQS queue name from URL:
    queue_name = queue_url.match(/[\w-]+$/)[0]

    # Extract endpoint for to connect to (protocol + fqdn + port)
    endpoint = queue_url.match(/https?:\/\/[^\/]+/)[0]

    { queue_url: queue_url, queue_name: queue_name, endpoint: endpoint }
  end

  def write (sqs_entry)
    begin
      Application.logger.debug "Writing deferred request id #{sqs_entry.id} to SQS: #{sqs_entry}"

      @sqs.send_message({
        message_group_id: MESSAGE_GROUP_ID,
        message_deduplication_id: sqs_entry.id,
        queue_url: @sqs_queue_url,
        message_body: JSON.generate(sqs_entry.request)
      })
    rescue Exception => e
      Application.logger.error "SqsClient error: #{e.message}"
      raise e
    end
  end
end
