# frozen_string_literal: true

require 'rails_helper'
require 'lib/preservation_catalog/shared_examples_provider'

describe PreservationCatalog::IbmProvider do
  it_behaves_like 'provider', described_class,
                  Settings.ibm.bucket_name,
                  Settings.zip_endpoints.ibm_us_south.region,
                  Settings.zip_endpoints.ibm_us_south.access_key_id,
                  Settings.zip_endpoints.ibm_us_south.secret_access_key

  describe '.resource' do
    let(:provider) do
      described_class.new(
        region: Settings.zip_endpoints.ibm_us_south.region,
        access_key_id: 'some_key',
        secret_access_key: 'secret'
      )
    end

    it 'builds a client with an http/s endpoint setting' do
      expect(::Aws::S3::Resource).to receive(:new).with(hash_including(endpoint: 'https://s3.us-south.cloud-object-storage.appdomain.cloud'))
      provider.resource
    end
  end
end
