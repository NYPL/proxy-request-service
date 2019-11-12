require 'aws-sdk-sqs'

require_relative 'spec_helper'

describe SqsClient do
  let(:mock_sqs_client) { instance_double(Aws::SQS::Client) }

  before(:each) do
    allow(Aws::SQS::Client).to receive(:new).and_return(mock_sqs_client)
    allow(mock_sqs_client).to receive(:send_message).and_return({ message_id: 'message-id' })
  end

  describe '#parse_sqs_url' do
    let(:mock_kms_client) { double('KmsClient', decrypt: 'https://example-domain:4576/queue/proxy-request-service' ) }

    before do
      allow(KmsClient).to receive(:new).and_return(mock_kms_client)
    end

    it 'parses sqs url correctly' do
      config = SqsClient.new.parse_sqs_url 'https://example-domain:4576/queue/proxy-request-service'
      expect(config[:queue_name]).to eq('proxy-request-service')
      expect(config[:queue_url]).to eq('https://example-domain:4576/queue/proxy-request-service')
      expect(config[:endpoint]).to eq('https://example-domain:4576')
    end
  end

  describe '#write' do

    let(:mock_job_client) { instance_double(JobClient) }

    before(:each) do
      allow(mock_job_client).to receive(:create_job).and_return('jobby-mc-job-job')
      allow(JobClient).to receive(:new).and_return(mock_job_client)
    end

    describe 'standard queue type' do
      let(:mock_kms_client) { double('KmsClient', decrypt: 'https://example-domain:4576/queue/proxy-request-service' ) }

      before do
        allow(KmsClient).to receive(:new).and_return(mock_kms_client)
      end

      it 'writes record to standard sqs' do
        ENV['SQS_QUEUE_URL'] = 'encrypted stuff, which mock_kms_client will "decrypt"'

        # Before handling anything, establish the kind of message we expect to be
        # sent to the Aws::SQS::Client#send_message
        # Note we have to do this *before* it is invoked
        expect(mock_sqs_client).to receive(:send_message).with(equivalent_sqs_entry_to({
          queue_url: 'https://example-domain:4576/queue/proxy-request-service',
          message_body: {
            url: 'http://example.com',
            body: { jobId: 'jobby-mc-job-job' }.to_json
          }.to_json
        }))

        response = SqsClient.new.write(DeferredRequest.new(url: 'http://example.com'))

        expect(response).to be_a(Hash)
        expect(response[:message_id]).to eq('message-id')
      end
    end

    describe 'FIFO queue type' do
      let(:mock_kms_client) { double('KmsClient', decrypt: 'https://example-domain:4576/queue/proxy-request-service.fifo' ) }

      before do
        allow(KmsClient).to receive(:new).and_return(mock_kms_client)
      end

      it 'writes record with dedupe params to FIFO sqs' do
        ENV['SQS_QUEUE_URL'] = 'encrypted stuff, which mock_kms_client will "decrypt"'

        # Before handling anything, establish the kind of message we expect to be
        # sent to the Aws::SQS::Client#send_message
        # Note we have to do this *before* it is invoked
        expect(mock_sqs_client).to receive(:send_message).with(equivalent_sqs_entry_to({
          message_group_id: 'proxy-requests',
          message_deduplication_id: 'message-id',
          queue_url: 'https://example-domain:4576/queue/proxy-request-service.fifo',
          message_body: {
            url: 'http://example.com',
            requestId: 'message-id',
            body: { jobId: 'jobby-mc-job-job' }.to_json
          }.to_json
        }))

        response = SqsClient.new.write(DeferredRequest.new(url: 'http://example.com', requestId: 'message-id'))

        expect(response).to be_a(Hash)
        expect(response[:message_id]).to eq('message-id')
      end
    end
  end
end
