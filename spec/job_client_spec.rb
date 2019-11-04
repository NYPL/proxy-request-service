require 'nypl_platform_api_client'

require_relative 'spec_helper'

describe JobClient do
  let(:mock_kms_client) { instance_double(Aws::KMS::Client) }
  let(:mock_platform_api_client) { instance_double(NyplPlatformApiClient) }

  before(:each) do
    allow(Aws::KMS::Client).to receive(:new).and_return(mock_kms_client)
    allow(mock_kms_client).to receive(:decrypt).and_return({ plaintext: 'decrypted-stuff' })

    allow(NyplPlatformApiClient).to receive(:new).and_return(mock_platform_api_client)
  end

  it "should extract id from created job" do
    allow(mock_platform_api_client).to receive(:post).and_return({ 'data' => { 'id' => '1234' } })

    expect(JobClient::generate_job_id).to eq('1234')
  end

  it "should raise error if JobService fails" do
    allow(mock_platform_api_client).to receive(:post).and_return(nil)
    expect { JobClient::generate_job_id }.to raise_error(JobServiceError)

    allow(mock_platform_api_client).to receive(:post).and_return({})
    expect { JobClient::generate_job_id }.to raise_error(JobServiceError)

    allow(mock_platform_api_client).to receive(:post).and_return({ 'data' => {} })
    expect { JobClient::generate_job_id }.to raise_error(JobServiceError)

    allow(mock_platform_api_client).to receive(:post).and_return("Plaintext response")
    expect { JobClient::generate_job_id }.to raise_error(JobServiceError)
  end
end
