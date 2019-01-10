require 'rails_helper'

describe PreservationCatalog::Ibm do
  describe '.resource' do
    it 'builds a client with an http/s endpoint setting' do
      zip_endpoints_setting = Config::Options.new(
        ibm_us_south:
          Config::Options.new(
            endpoint_node: 'https://ibm.endpoint.biz',
            storage_location: 'storage_location',
            delivery_class: 'IbmSouthDeliveryJob'
          )
      )
      allow(Settings).to receive(:zip_endpoints).and_return(zip_endpoints_setting)
      expect(Aws::S3::Resource).to receive(:new).with(hash_including(endpoint: 'https://ibm.endpoint.biz'))
      described_class.resource
    end
  end
end
