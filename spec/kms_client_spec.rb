require 'aws-sdk-kms'

require_relative 'spec_helper'

describe KmsClient do
  let(:mock_kms_client) { instance_double(Aws::KMS::Client) }

  before(:each) do
    allow(Aws::KMS::Client).to receive(:new).and_return(mock_kms_client)
    allow(mock_kms_client).to receive(:decrypt).and_return({ plaintext: 'decrypted-stuff' })
  end

  it "should extract decrypted value from kms response" do
    expect(KmsClient.new.decrypt('encrypted-stuff')).to eq('decrypted-stuff')
  end
end
