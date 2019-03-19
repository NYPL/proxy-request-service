require_relative './spec_helper'

require_relative '../app'

describe 'app', :type => :controller do
  before do
    $initialized = true

    $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

    $sqs_client = instance_double('SqsClient')
    allow($sqs_client).to receive(:write).and_return({ message_id: 'fake-message-id' })
  end

  describe '#handle_event' do
    it 'rejects invalid request method' do
      event = {
        "httpMethod" => "GET"
      }
      response = handle_event(event: event, context: {})
      expect(response).to be_a(Hash)
      expect(response[:statusCode]).to eq(400)
      expect(response[:body]).to be_a(String)
      expect(JSON.parse(response[:body])).to be_a(Hash)
      expect(JSON.parse(response[:body])['message']).to eq("RequestError: Invalid request method; Only POST, PUT, PATCH, DELETE supported")
    end

    it 'rejects invalid request path' do
      event = {
        "httpMethod" => "POST",
        "path" => "/wp-admin"
      }
      response = handle_event(event: event, context: {})
      expect(response).to be_a(Hash)
      expect(response[:statusCode]).to eq(400)
      expect(response[:body]).to be_a(String)
      expect(JSON.parse(response[:body])).to be_a(Hash)
      expect(JSON.parse(response[:body])['message']).to eq("RequestError: Invalid request path; Only paths that begin /api/v0.1/ supported")
    end

    it 'accepts and writes a valid event' do
      event = {
        "httpMethod" => "POST",
        "path" => "/api/v0.1/some-endpoint",
        "body" => "{ \"foo\": \"bar\" }",
        "queryStringParameters" => "{ \"foo2\": \"bar2\" }"
      }
      response = handle_event(event: event, context: {})
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
