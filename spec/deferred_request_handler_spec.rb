require 'aws-sdk-sqs'
require 'webmock/rspec'

require_relative 'spec_helper'

describe DeferredRequestHandler do
  let(:sqs_client) { instance_double(Aws::SQS::Client) }
  let(:mock_kms_client) { double('KmsClient', decrypt: 'https://example-domain:4576/queue/proxy-request-service' ) }

  before do
    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
    allow(sqs_client).to receive(:send_message).and_return({ message_id: 'message-id' })

    allow(KmsClient).to receive(:new).and_return(mock_kms_client)

    ENV['PLATFORM_API_BASE_URL'] = 'https://example.com/api/v0.1/'
    ENV['NYPL_OAUTH_ID'] = Base64.strict_encode64 'fake-client'
    ENV['NYPL_OAUTH_SECRET'] = Base64.strict_encode64 'fake-secret'
    ENV['NYPL_OAUTH_URL'] = 'https://isso.example.com/'

    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')
    stub_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}jobs").to_return(status: 200, body: '{ "data": { "id": "jobby-jobby-id" } }')
  end

  describe '#handle' do
    it 'should write record to sqs with generated job id' do
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
        queue_url: 'https://example-domain:4576/queue/proxy-request-service',
        # Stringify the message_body:
        message_body: {
          "httpMethod": "POST",
          "path": "/api/v0.1/path",
          # Further stringify the JSON payload:
          "body": { "jobId": "jobby-jobby-id" }.to_json,
          "isBase64Encoded": nil,
          "headers": nil,
          "queryStringParameters": nil,
          "requestId": "unique-request-id"
        }.to_json
      }))

      response = DeferredRequestHandler.new.handle(event)

      expect(response).to be_a(Hash)
      expect(response[:statusCode]).to eq(200)
      expect(response[:body]).to be_a(String)
      expect(response[:headers]).to be_a(Hash)
      expect(response[:headers][:"Content-Type"]).to eq('application/json')

      body = JSON.parse(response[:body])
      expect(body['success']).to eq(true)
      expect(body['sqsResult']).to be_a(Hash)
      expect(body['sqsResult']['message_id']).to be_a(String)
      expect(body['data']).to be_a(Hash)
      expect(body['data']['jobId']).to be_a(String)
      expect(body['data']['jobId']).to eq('jobby-jobby-id')
    end

    it 'should write record to sqs without jobid if proxyServiceCreateJob=false' do
      ENV['SQS_QUEUE_URL'] = 'encrypted-stuff'

      event = {
        "path" => "/api/v0.1/path",
        "httpMethod" => "POST",
        "queryStringParameters" => {
          # This is the method for overriding job creation, which defaults true
          "proxyServiceCreateJob" => 'false'
        },
        "requestContext" => { "requestId" => "unique-request-id" }
      }

      # Before handling anything, establish the kind of message we expect to be
      # sent to the Aws::SQS::Client#send_message
      # Note we have to do this *before* it is invoked
      expect(sqs_client).to receive(:send_message).with(equivalent_sqs_entry_to({
        queue_url: 'https://example-domain:4576/queue/proxy-request-service',
        # Stringify the message_body:
        message_body: {
          "httpMethod": "POST",
          "path": "/api/v0.1/path",
          # Expect no jobId in the body:
          "body": nil,
          "isBase64Encoded": nil,
          "headers": nil,
          # Expect the :proxyServiceCreateJob param to have been deleted:
          "queryStringParameters": {},
          "requestId": "unique-request-id"
        }.to_json
      }))

      response = DeferredRequestHandler.new.handle(event)

      expect(response).to be_a(Hash)
      expect(response[:statusCode]).to eq(200)
      expect(response[:body]).to be_a(String)
      expect(response[:headers]).to be_a(Hash)
      expect(response[:headers][:"Content-Type"]).to eq('application/json')

      body = JSON.parse(response[:body])
      expect(body['success']).to eq(true)
      expect(body['sqsResult']).to be_a(Hash)
      expect(body['sqsResult']['message_id']).to be_a(String)
      expect(body['jobId']).to be_nil
    end
  end
end
