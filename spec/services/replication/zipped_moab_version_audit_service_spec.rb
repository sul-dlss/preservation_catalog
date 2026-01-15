# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::ZippedMoabVersionAuditService do
  let(:preserved_object) { create(:preserved_object_fixture, druid: 'bj102hs9687') }
  let(:md5_checksum) { '00236a2ae558018ed13b5222ef1bd977' }

  let(:delivery_job) { instance_double(Replication::S3WestDeliveryJob, bucket:) }
  let(:bucket) { instance_double(Aws::S3::Bucket, object: s3_object) }
  let(:s3_object) { instance_double(Aws::S3::Object, exists?: true, metadata: { 'checksum_md5' => md5_checksum }) }
  let(:provider) { instance_double(Replication::AwsProvider, bucket:) }

  let(:missing_s3_object) { instance_double(Aws::S3::Object, exists?: false, bucket_name: 'test-bucket') }
  let(:mismatch_s3_object) do
    instance_double(Aws::S3::Object, exists?: true, metadata: { 'checksum_md5' => 'incorrect_checksum' }, bucket_name: 'test-bucket')
  end

  let(:results) { instance_double(Results, add_result: nil, to_s: 'new status details') }

  before do
    allow(Replication::ProviderFactory).to receive(:create).and_return(provider)
  end

  context 'when a ZippedMoabVersion with nil zip_parts_count' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, zip_parts_count: nil, status: :failed, preserved_object: preserved_object).tap do |zipped_moab_version|
        create_list(:zip_part, 3, zipped_moab_version:, md5: md5_checksum, size: 10_000_000)
      end
    end

    before do
      allow(bucket).to receive(:object).and_return(s3_object)
    end

    it 'sets zip_parts_count to actual count' do
      expect { described_class.call(zipped_moab_version:, results:) }
        .to change { zipped_moab_version.reload.zip_parts_count }.from(nil).to(3)
        .and change(zipped_moab_version, :status).to('ok')
        .and change(zipped_moab_version, :status_details).from(nil).to('new status details')
    end
  end

  context 'when a ZippedMoabVersion with no issues' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, zip_parts_count: 3, status: :failed, preserved_object: preserved_object).tap do |zipped_moab_version|
        create_list(:zip_part, 3, zipped_moab_version:, md5: md5_checksum, size: 10_000_000)
      end
    end

    it 'changes status to ok and returns no audit results' do
      expect { described_class.call(zipped_moab_version:, results:) }
        .to change { zipped_moab_version.reload.status }.to('ok')
      expect(results).not_to have_received(:add_result)
    end
  end

  context 'when a ZippedMoabVersion with no ZipParts' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, status: :ok, preserved_object: preserved_object)
    end

    it 'adds an audit result and changes status to created' do
      expect { described_class.call(zipped_moab_version:, results:) }
        .to change { zipped_moab_version.reload.status }.to('created')
      expect(results).to have_received(:add_result).with(
        Results::ZIP_PARTS_NOT_CREATED,
        hash_including(
          version: zipped_moab_version.version,
          endpoint_name: zipped_moab_version.zip_endpoint.endpoint_name
        )
      )
    end
  end

  context 'when a created ZippedMoabVersion with no ZipParts' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, status: :created, preserved_object: preserved_object)
    end

    it 'adds an audit result and leaves status' do
      expect { described_class.call(zipped_moab_version:, results:) }
        .not_to(change { zipped_moab_version.reload.status })
      expect(results).to have_received(:add_result).with(
        Results::ZIP_PARTS_NOT_CREATED, Hash
      )
    end
  end

  context 'when a ZippedMoabVersion with inconsistent zip part sizes' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, zip_parts_count: 3, status: :ok, preserved_object: preserved_object).tap do |zipped_moab_version|
        create_list(:zip_part, 3, zipped_moab_version:, md5: md5_checksum, size: 100)
      end
    end

    it 'changes the status to failed and adds an audit result' do
      expect { described_class.call(zipped_moab_version:, results:) }
        .to change { zipped_moab_version.reload.status }.to('failed')
      expect(results).to have_received(:add_result).with(
        Results::ZIP_PARTS_SIZE_INCONSISTENCY,
        hash_including(
          total_part_size: 300,
          moab_version_size: 1_928_387
        )
      )
    end
  end

  context 'when a ZippedMoabVersion with inconsistent zip part counts' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, zip_parts_count: 3, status: :ok, preserved_object: preserved_object).tap do |zipped_moab_version|
        create_list(:zip_part, 2, zipped_moab_version:, md5: md5_checksum, size: 10_000_000)
      end
    end

    it 'changes the status to failed and adds an audit result' do
      expect { described_class.call(zipped_moab_version:, results:) }
        .to change { zipped_moab_version.reload.status }.to('failed')
      expect(results).to have_received(:add_result).with(
        Results::ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL,
        hash_including(
          db_count: 3,
          actual_count: 2
        )
      )
    end
  end

  context 'when a ZippedMoabVersion with checksum mismatches' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, zip_parts_count: 3, status: :ok, preserved_object: preserved_object).tap do |zipped_moab_version|
        create_list(:zip_part, 3, zipped_moab_version:, md5: md5_checksum, size: 10_000_000)
      end
    end

    before do
      allow(bucket).to receive(:object).and_return(s3_object, mismatch_s3_object, s3_object)
    end

    it 'changes the status to failed and adds an audit result' do
      expect { described_class.call(zipped_moab_version:, results:) }
        .to change { zipped_moab_version.reload.status }.to('failed')
      expect(results).to have_received(:add_result).with(
        Results::ZIP_PART_CHECKSUM_MISMATCH,
        hash_including(
          bucket_name: 'test-bucket',
          endpoint_name: zipped_moab_version.zip_endpoint.endpoint_name,
          md5: '00236a2ae558018ed13b5222ef1bd977',
          replicated_checksum: 'incorrect_checksum',
          s3_key: zipped_moab_version.zip_parts.second.s3_key
        )
      )
    end
  end

  context 'when a ZippedMoabVersion with missing zip parts' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, zip_parts_count: 3, status: :ok, preserved_object: preserved_object).tap do |zipped_moab_version|
        create_list(:zip_part, 3, zipped_moab_version:, md5: md5_checksum, size: 10_000_000)
      end
    end

    before do
      allow(bucket).to receive(:object).and_return(s3_object, missing_s3_object, s3_object)
    end

    it 'changes the status to incomplete and adds an audit result' do
      expect { described_class.call(zipped_moab_version:, results:) }
        .to change { zipped_moab_version.reload.status }.to('incomplete')
      expect(results).to have_received(:add_result).with(
        Results::ZIP_PART_NOT_FOUND,
        hash_including(
          bucket_name: 'test-bucket',
          endpoint_name: zipped_moab_version.zip_endpoint.endpoint_name,
          s3_key: zipped_moab_version.zip_parts.second.s3_key
        )
      )
    end
  end

  context 'when an incomplete ZippedMoabVersion with missing zip parts' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, zip_parts_count: 3, status: :incomplete, preserved_object: preserved_object).tap do |zipped_moab_version|
        create_list(:zip_part, 3, zipped_moab_version:, md5: md5_checksum, size: 10_000_000)
      end
    end

    before do
      allow(bucket).to receive(:object).and_return(s3_object, missing_s3_object, s3_object)
    end

    it 'does not change status but adds an audit result' do
      expect { described_class.call(zipped_moab_version:, results:) }
        .not_to(change { zipped_moab_version.reload.status })

      expect(results).to have_received(:add_result).with(
        Results::ZIP_PARTS_NOT_ALL_REPLICATED, Hash
      )
    end
  end
end
