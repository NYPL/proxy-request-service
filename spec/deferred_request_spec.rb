require_relative 'spec_helper'

describe DeferredRequest do
  before(:each) do
    allow(JobClient).to receive(:generate_job_id).and_return('1234')
  end

  describe '#should_create_job?' do
    it 'defaults to creating job' do
      expect(DeferredRequest.should_create_job?({ })).to eq(true)
      expect(DeferredRequest.should_create_job?({ :queryStringParameters => nil })).to eq(true)
      expect(DeferredRequest.should_create_job?({ :queryStringParameters => { } })).to eq(true)
      expect(DeferredRequest.should_create_job?({ :queryStringParameters => { 'foo' => 'bar' } })).to eq(true)
      expect(DeferredRequest.should_create_job?({ :queryStringParameters => { 'proxyServiceCreateJob' => 'true' } })).to eq(true)
    end

    it 'skip job creation if proxyServiceCreateJob is set to anything but true' do
      expect(DeferredRequest.should_create_job?({ :queryStringParameters => { 'proxyServiceCreateJob' => '1' } })).to eq(false)
      expect(DeferredRequest.should_create_job?({ :queryStringParameters => { 'proxyServiceCreateJob' => 'false' } })).to eq(false)
    end
  end

  describe '#for_event' do
    it 'builds sqs record with only the essential request data' do
      event = {
        "httpMethod" => "POST",
        "path" => "/api/v0.1/some-endpoint",
        "body" => "{ \"foo\": \"bar\" }",
        "queryStringParameters" => "{ \"foo2\": \"bar2\" }",
        "headers" => { "Content-Type": "application/nes-rom" }
      }
      record = DeferredRequest.for_event event

      expect(record.request).to be_a(Hash)
      expect(record.request[:httpMethod]).to eq('POST')
      expect(record.request[:path]).to eq('/api/v0.1/some-endpoint')

      expect(record.request[:body]).to be_a(String)
      body = JSON.parse(record.request[:body])
      expect(body["foo"]).to eq('bar')
      expect(body["jobId"]).to eq('1234')

      expect(record.request[:queryStringParameters]).to be_a(String)
      queryString = JSON.parse(record.request[:queryStringParameters])
      expect(queryString["foo2"]).to eq('bar2')

      expect(record.request[:headers]).to be_a(Hash)
      expect(record.request[:headers][:"Content-Type"]).to eq('application/nes-rom')

      expect(record.request[:isBase64Encoded]).to eq(nil)
    end

    it 'builds sqs record stripped of Authorization header' do
      event = {
        "httpMethod" => "POST",
        "path" => "/api/v0.1/some-endpoint",
        "headers" => { "Content-Type": "application/nes-rom", "Authorization": "Bearer abc" }
      }
      record = DeferredRequest.for_event event

      expect(record.request).to be_a(Hash)

      expect(record.request[:headers]).to be_a(Hash)
      expect(record.request[:headers][:"Content-Type"]).to eq('application/nes-rom')
      expect(record.request[:headers][:"Authorization"]).to be_nil
    end
  end
end
