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

    # if ENV['AWS_ACCESS_KEY_ID']
    #   @sqs = Aws::SQS::Client.new(
    #     region: 'us-east-1',
    #     access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    #     secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    #     endpoint: sqs_config[:endpoint]
    #   )   
    # else   
    @sqs = Aws::SQS::Client.new(
      region: 'us-east-1',
      endpoint: sqs_config[:endpoint]
    )   
    # end
  end

  # Parses given SQS URL, returning a Hash with:
  #   queue_url: The original URL
  #   queue_name: The name part of the URL (e.g. "proxy-request-queue-qa"
  #   endpoint: The protocol & fqdn of the URL
  def parse_sqs_url (queue_url)
    # Strip rogue whitespace from encrypted value:
    queue_url.strip!

    # Extract SQS queue name from URL:
    queue_name = queue_url.match(/[\w-]+$/)[0]

    # Extract endpoint for to connect to (protocol + fqdn + port)
    endpoint = queue_url.match(/https?:\/\/[^\/]+/)[0]

    { queue_url: queue_url, queue_name: queue_name, endpoint: endpoint }
  end

  # Is the queue we're writing to a "FIFO" queue type?
  def is_fifo_queue?
    # AWS SQA requires FIFO queues to end in ".fifo"
    ! @sqs_queue_url.match(/\.fifo/).nil?
  end

  # Write `entry` to SQS
  def write (sqs_entry)
    begin
      Application.logger.debug "Writing deferred request id #{sqs_entry.id} to SQS: #{sqs_entry}"

      message = {
        queue_url: @sqs_queue_url,
        message_body: JSON.generate(sqs_entry.serialize)
      }

      # Include deduplication params if writing to a FIFO queue:
      if is_fifo_queue?
        message[:message_group_id] = MESSAGE_GROUP_ID
        message[:message_deduplication_id] = sqs_entry.id
      end

      @sqs.send_message(message)
    rescue Exception => e
      Application.logger.error "SqsClient error: #{e.message}"
      raise e
    end
  end
end
