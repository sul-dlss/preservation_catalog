# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::ReplicationSupport do
  let(:druid) { 'bz514sm9647' }
  let(:zmv) { create(:zipped_moab_version, preserved_object: create(:preserved_object_fixture, druid:)) }
  let(:results) { Audit::Results.new(druid: zmv.preserved_object.druid, moab_storage_root: zmv.zip_endpoint, check_name: 'ReplicationSupportSpec') }
  let(:version) { zmv.version }
  let(:endpoint_name) { zmv.zip_endpoint.endpoint_name }
  let(:result_prefix) { "#{version} on #{endpoint_name}" }

  describe '.check_child_zip_part_attributes' do
    context 'when zip parts have not been created yet' do
      it 'logs an error indicating that zip parts have not beeen created yet' do
        described_class.check_child_zip_part_attributes(zmv, results)
        expect(results.results).to include(
          a_hash_including(
            Audit::Results::ZIP_PARTS_NOT_CREATED => "#{result_prefix}: no zip_parts exist yet for this ZippedMoabVersion"
          )
        )
      end

      it 'returns false' do
        expect(described_class.check_child_zip_part_attributes(zmv, results)).to be(false)
      end
    end

    context 'when different parts have different expected parts_count values' do
      before do
        args = attributes_for(:zip_part)
        zmv.zip_parts.create!(
          [
            args.merge(status: 'ok', parts_count: 2, suffix: '.zip'),
            args.merge(status: 'ok', parts_count: 2, suffix: '.z01'),
            args.merge(status: 'ok', parts_count: 3, suffix: '.z02')
          ]
        )
      end

      it 'logs the discrepancy' do
        described_class.check_child_zip_part_attributes(zmv, results)
        child_parts_counts = zmv.child_parts_counts
        exp_err_msg = "#{result_prefix}: ZippedMoabVersion has variation in child parts_counts: #{child_parts_counts}"
        expect(results.results).to include(
          a_hash_including(Audit::Results::ZIP_PARTS_COUNT_INCONSISTENCY => exp_err_msg)
        )
      end
    end

    context 'when parts_count is consistent across parts with the actual number of zip parts' do
      before do
        args = attributes_for(:zip_part)
        zmv.zip_parts.create!(
          [
            args.merge(status: 'ok', parts_count: 3, suffix: '.zip'),
            args.merge(status: 'ok', parts_count: 3, suffix: '.z01'),
            args.merge(status: 'ok', parts_count: 3, suffix: '.z02')
          ]
        )
      end

      it "doesn't log parts_count errors" do
        described_class.check_child_zip_part_attributes(zmv, results)
        expect(results.results).not_to include(a_hash_including(Audit::Results::ZIP_PARTS_COUNT_INCONSISTENCY))
      end

      it "doesn't log an error about parts_count mismatching number of zip_parts" do
        described_class.check_child_zip_part_attributes(zmv, results)
        expect(results.results).not_to include(a_hash_including(Audit::Results::ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL))
      end
    end

    context "when parts_count is consistent across parts, but doesn't match the actual number of child parts" do
      before do
        args = attributes_for(:zip_part)
        zmv.zip_parts.create!(
          [
            args.merge(status: 'ok', parts_count: 3, suffix: '.zip'),
            args.merge(status: 'ok', parts_count: 3, suffix: '.z01')
          ]
        )
      end

      it 'logs the discrepancy' do
        described_class.check_child_zip_part_attributes(zmv, results)
        msg = "#{result_prefix}: ZippedMoabVersion stated parts count " \
              "(3) doesn't match actual number of zip parts rows (2)"
        expect(results.results).to include(
          a_hash_including(Audit::Results::ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL => msg)
        )
      end
    end

    context 'when total part size is less than the moab size' do
      before do
        args = attributes_for(:zip_part)
        zmv.zip_parts.create!(
          [
            args.merge(status: 'ok', parts_count: 3, suffix: '.zip', size: 111),
            args.merge(status: 'ok', parts_count: 3, suffix: '.z01', size: 222),
            args.merge(status: 'ok', parts_count: 3, suffix: '.z02', size: 333)
          ]
        )
      end

      it 'logs the discrepancy' do
        described_class.check_child_zip_part_attributes(zmv, results)
        msg = "#{result_prefix}: Sum of ZippedMoabVersion child part sizes (666) is less than what is in the Moab: 202938"
        expect(results.results).to include(
          a_hash_including(Audit::Results::ZIP_PARTS_SIZE_INCONSISTENCY => msg)
        )
      end
    end

    context 'when zip parts have been created and some parts are unreplicated' do
      before do
        args = attributes_for(:zip_part)
        zmv.zip_parts.create!(
          [
            args.merge(status: 'unreplicated', parts_count: 3, suffix: '.zip'),
            args.merge(status: 'ok', parts_count: 3, suffix: '.z01'),
            args.merge(status: 'unreplicated', parts_count: 3, suffix: '.z02')
          ]
        )
      end

      it 'logs' do
        msg = "#{result_prefix}: not all ZippedMoabVersion parts are replicated yet"
        described_class.check_child_zip_part_attributes(zmv, results)
        expect(results.results).to include(a_hash_including(Audit::Results::ZIP_PARTS_NOT_ALL_REPLICATED => msg))
      end

      it 'returns true' do
        expect(described_class.check_child_zip_part_attributes(zmv, results)).to be(true)
      end
    end
  end

  describe '.zip_part_debug_info' do
    subject(:debug_info) { described_class.zip_part_debug_info(zip_part.druid) }

    let(:zip_part) { create(:zip_part, zipped_moab_version: zmv) }
    let(:s3_object) { instance_double(Aws::S3::Object, exists?: true, metadata: { 'checksum_md5' => '00236a2ae558018ed13b5222ef1bd977' }) }
    let(:provider) { instance_double(Replication::AwsProvider, bucket: instance_double(Aws::S3::Bucket, object: s3_object)) }

    before { allow(Replication::ProviderFactory).to receive(:create).and_return(provider) }

    it 'returns a hash of zip part info sufficient to do troubleshooting' do
      expect(debug_info).to include(a_hash_including(druid:,
                                                     preserved_object_version: 3,
                                                     zipped_moab_version: 1,
                                                     endpoint_name: /endpoint\d+/,
                                                     status: 'unreplicated',
                                                     suffix: /\.z\d+/,
                                                     parts_count: 1,
                                                     size: 1234,
                                                     md5: '00236a2ae558018ed13b5222ef1bd977',
                                                     id: zip_part.id,
                                                     s3_key: %r{bz/514/sm/9647/bz514sm9647\.v0001\.z\d+},
                                                     found_at_endpoint: 'found at endpoint',
                                                     checksum_md5: '00236a2ae558018ed13b5222ef1bd977'))
    end
  end
end
