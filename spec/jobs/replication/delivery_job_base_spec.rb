# frozen_string_literal: true

require 'rails_helper'

describe Replication::DeliveryJobBase do
  # NOTE: Test a concrete impl of the base job so the call to `#bucket` does not raise
  subject(:job_implementation) do
    Class.new(described_class) do
      def bucket
        Struct.new(:unused) do
          def object(arg); end
        end.new
      end
    end
  end

  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:dvz) { Replication::DruidVersionZip.new(druid, version) }
  let(:dvz_part) { Replication::DruidVersionZipPart.new(dvz, part_s3_key) }
  let(:metadata) { dvz_part.metadata.merge(zip_version: 'Zip 3.0 (July 5th 2008)') }
  let(:part_s3_key) { dvz.s3_key('.zip') }
  let(:delivery_result) { true }

  before do
    allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    allow(Replication::ResultsRecorderJob).to receive(:perform_later)
    allow(Replication::ZipDeliveryService).to receive(:deliver).and_return(delivery_result)

    job_implementation.perform_now(druid, version, part_s3_key, metadata)
  end

  context 'when zip delivery succeeds' do
    it 'invokes Replication::ResultsRecorderJob' do
      expect(Replication::ResultsRecorderJob).to have_received(:perform_later).with(druid, version, part_s3_key, job_implementation.to_s)
    end
  end

  context 'when zip delivery fails' do
    let(:delivery_result) { nil }

    it 'does nothing' do
      expect(Replication::ResultsRecorderJob).not_to have_received(:perform_later)
    end
  end

  describe '#bucket' do
    it 'raises NotImplementedError' do
      expect { described_class.new.bucket }.to raise_error(NotImplementedError)
    end
  end
end
