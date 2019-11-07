require_relative 'spec_helper'

require_relative File.join('..', 'application')
require_relative File.join('..', 'lib', 'kms_client')

describe Application do
  let(:mock_sqs_client) { double('SqsClient', write: { message_id: 'message id' } ) }

  before do
    allow(SqsClient).to receive(:new).and_return(mock_sqs_client)
    allow(JobClient).to receive(:generate_job_id).and_return('1234')
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

    it 'accepts and writes a valid event', current: true do
      event = {
        "httpMethod" => "POST",
        "path" => "/api/v0.1/some-endpoint",
        "body" => "{ \"foo\": \"bar\", \"itemBarcode\": \"item-barcode\" }",
        "queryStringParameters" => { "foo2": "bar2" },
        "requestContext": {
          "requestId": "c6af9ac6-7b61-11e6-9a41-93e8deadbeef"
        }
      }
      response = handle_event(event: event, context: {})
      expect(response).to be_a(Hash)
      expect(response[:statusCode]).to eq(200)
      expect(response[:body]).to be_a(String)
      expect(response[:headers]).to be_a(Hash)
      expect(response[:headers][:"Content-Type"]).to eq('application/json')

      body = JSON.parse(response[:body])
      expect(body['success']).to eq(true)
      expect(body['sqsResult']).to be_a(Hash)
      expect(body['sqsResult']['message_id']).to be_a(String)
      expect(body['jobId']).to eq('1234')
      expect(body['itemBarcode']).to eq('item-barcode')
    end
  end
end
