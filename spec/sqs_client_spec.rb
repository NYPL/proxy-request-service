require 'aws-sdk-sqs'

require_relative 'spec_helper'

describe SqsClient do
  let(:sqs_client) { instance_double(Aws::SQS::Client) }
  let(:mock_kms_client) { double('KmsClient', decrypt: 'https://example-domain:4576/queue/proxy-request-service' ) }

  before do
    sqs_client = instance_double(Aws::SQS::Client)
    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
    allow(sqs_client).to receive(:send_message).and_return({ message_id: 'message-id' })

    allow(KmsClient).to receive(:new).and_return(mock_kms_client)
  end

  describe '#parse_sqs_url' do
    it 'parses sqs url correctly' do
      config = SqsClient.new.parse_sqs_url 'https://example-domain:4576/queue/proxy-request-service'
      expect(config[:queue_name]).to eq('proxy-request-service')
      expect(config[:queue_url]).to eq('https://example-domain:4576/queue/proxy-request-service')
      expect(config[:endpoint]).to eq('https://example-domain:4576')
    end
  end

  describe '#write' do
    it 'writes record to sqs' do
      ENV['SQS_QUEUE_URL'] = 'http://localhost:4576/queue/proxy-request-service'

      response = SqsClient.new.write(DeferredRequest.new(url: 'http://example.com'))

      expect(response).to be_a(Hash)
      expect(response[:message_id]).to eq('message-id')
    end
  end
end
