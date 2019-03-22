require 'aws-sdk-sqs'

require_relative 'spec_helper'

RSpec::Matchers.define :equivalent_sqs_entry_to do |model|
  match do |actual|
    actual &&
      model[:message_group_id] == actual[:message_group_id] &&
      model[:message_deduplication_id] == actual[:message_deduplication_id] &&
      model[:queue_url] == actual[:queue_url] &&
      model[:message_body] == actual[:message_body]
  end
end

describe DeferredRequestHandler do
  let(:sqs_client) { instance_double(Aws::SQS::Client) }
  let(:mock_kms_client) { double('KmsClient', decrypt: 'https://example-domain:4576/queue/proxy-request-service' ) }

  before do
    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
    allow(sqs_client).to receive(:send_message).and_return({ message_id: 'message-id' })

    allow(KmsClient).to receive(:new).and_return(mock_kms_client)
  end

  describe '#handle' do
    it 'writes record to sqs' do
      ENV['SQS_QUEUE_URL'] = 'encrypted-stuff'

      event = {
        "path" => "/api/v0.1/path",
        "httpMethod" => "POST",
        "requestContext" => { "requestId" => "unique-request-id" }
      }

      # Before handling anything, establish the kind of message we expect to be
      # sent to the Aws::SQS::Client#send_message
      # Note we have to do this *before* it is invoked
      expect(sqs_client).to receive(:send_message).with(equivalent_sqs_entry_to({
        message_group_id: 'proxy-requests',
        message_deduplication_id: event['requestContext']['requestId'],
        queue_url: 'https://example-domain:4576/queue/proxy-request-service',
        message_body: "{\"httpMethod\":\"POST\",\"path\":\"/api/v0.1/path\",\"body\":null,\"isBase64Encoded\":null,\"headers\":null,\"queryStringParameters\":null,\"requestId\":\"unique-request-id\"}"
      }))

      response = DeferredRequestHandler.new.handle(event)

      expect(response).to be_a(Hash)
      expect(response[:statusCode]).to eq(200)
      expect(response[:body]).to be_a(String)
      expect(response[:headers]).to be_a(Hash)
      expect(response[:headers][:"Content-Type"]).to eq('application/json')

      body = JSON.parse(response[:body])
      expect(body['success']).to eq(true)
      expect(body['result']).to be_a(Hash)
      expect(body['result']['message_id']).to be_a(String)

    end
  end
end
