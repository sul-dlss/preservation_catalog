# frozen_string_literal: true

RSpec.shared_examples 'replication to endpoint' do |provider_class, bucket_name, check_name, endpoint_name, region|
  let(:zip_endpoint) do
    ZipEndpoint.find_by(endpoint_name: endpoint_name)
  end
  let(:zmv) do
    create(:zipped_moab_version, zip_endpoint: zip_endpoint)
  end
  let(:bucket) { instance_double(Aws::S3::Bucket) }
  let(:bucket_name) { bucket_name }
  let(:matching_md5) { attributes_for(:zip_part)[:md5] }
  let(:non_matching_md5) { 'asdfasdfb43t347l;x5px54xx6549;f4' }
  let(:results) { Audit::Results.new(druid: zmv.preserved_object.druid, moab_storage_root: zmv.zip_endpoint, check_name: check_name) }
  let(:endpoint_name) { zmv.zip_endpoint.endpoint_name }
  let(:provider) { instance_double(provider_class) }

  before do
    allow(Audit::Results).to receive(:new).and_return(results)
    allow(provider_class).to receive(:new).and_return(provider)
    allow(provider).to receive_messages(bucket: bucket, bucket_name: bucket_name)
  end

  context 'some parts are unreplicated' do
    before do
      args = attributes_for(:zip_part)
      zmv.zip_parts.create!(
        [
          args.merge(status: 'unreplicated', parts_count: 3, suffix: '.zip'),
          args.merge(status: 'ok', parts_count: 3, suffix: '.z01'),
          args.merge(status: 'unreplicated', parts_count: 3, suffix: '.z02')
        ]
      )

      # fine to assume existence and matching checksum for all parts for this test case
      allow(bucket).to receive(:object).and_return(
        instance_double(Aws::S3::Object, exists?: true, metadata: { 'checksum_md5' => args[:md5] })
      )
    end

    it 'only checks existence and checksum on replicated parts' do
      part1 = zmv.zip_parts.find_by(suffix: '.zip')
      part3 = zmv.zip_parts.find_by(suffix: '.z02')
      ok_part = zmv.zip_parts.find_by(suffix: '.z01')
      s3_obj = instance_double(Aws::S3::Object, exists?: true)

      expect(bucket).to receive(:object).with(ok_part.s3_key).and_return(s3_obj)
      expect(s3_obj).to receive(:metadata).and_return('checksum_md5' => ok_part.md5)
      expect(bucket).not_to receive(:object).with(part1.s3_key)
      expect(bucket).not_to receive(:object).with(part3.s3_key)
      expect { described_class.check_replicated_zipped_moab_version(zmv, results) }
        .to change { ok_part.reload.last_existence_check }
        .from(nil)
        .and change { ok_part.reload.last_checksum_validation }
        .from(nil)
    end

    context 'check_unreplicated_parts is true' do
      let(:part1) { zmv.zip_parts.find_by(suffix: '.zip') }
      let(:part2) { zmv.zip_parts.find_by(suffix: '.z01') }
      let(:part3) { zmv.zip_parts.find_by(suffix: '.z02') }
      let(:s3_obj_part1) { instance_double(Aws::S3::Object, exists?: false) }
      let(:s3_obj_part2) { instance_double(Aws::S3::Object, exists?: true) }
      let(:s3_obj_part3) { instance_double(Aws::S3::Object, exists?: true) }

      before do
        allow(bucket).to receive(:object).with(part1.s3_key).and_return(s3_obj_part1)
        allow(bucket).to receive(:object).with(part2.s3_key).and_return(s3_obj_part2)
        allow(bucket).to receive(:object).with(part3.s3_key).and_return(s3_obj_part3)
      end

      it 'checks existence on all parts, and metadata on any parts present in the cloud' do
        expect(s3_obj_part1).not_to receive(:metadata) # no metadata to check since cloud copy doesn't exist
        expect(s3_obj_part2).to receive(:metadata).and_return('checksum_md5' => part2.md5)
        expect(s3_obj_part3).to receive(:metadata).and_return('checksum_md5' => part3.md5)
        expect { described_class.check_replicated_zipped_moab_version(zmv, results, true) }
          .to change { part1.reload.last_existence_check }
          .from(nil)
          .and change { part2.reload.last_existence_check }
          .from(nil)
          .and change { part2.reload.last_checksum_validation }
          .from(nil)
          .and change { part3.reload.last_existence_check }
          .from(nil)
          .and change { part3.reload.last_checksum_validation }
          .from(nil)
        expect(part1.reload.last_checksum_validation).to be_nil
      end

      it 'leaves unfound unreplicated parts and found ok in their respective current statuses' do
        allow(s3_obj_part2).to receive(:metadata).and_return('checksum_md5' => part2.md5)
        allow(s3_obj_part3).to receive(:metadata).and_return('checksum_md5' => part3.md5)
        expect { described_class.check_replicated_zipped_moab_version(zmv, results, true) }
          .not_to change { part1.reload.status }.from('unreplicated')
        expect { described_class.check_replicated_zipped_moab_version(zmv, results, true) }
          .not_to change { part2.reload.status }.from('ok')
      end

      it 'updates status on parts that are found' do
        allow(s3_obj_part2).to receive(:metadata).and_return('checksum_md5' => part2.md5)
        allow(s3_obj_part3).to receive(:metadata).and_return('checksum_md5' => part3.md5)
        expect { described_class.check_replicated_zipped_moab_version(zmv, results, true) }
          .to change { part3.reload.status }.from('unreplicated').to('ok')
      end
    end

    it 'configures S3' do
      described_class.check_replicated_zipped_moab_version(zmv, results)
      # Note that access_key_id and secret_access_key are provided by env variables in CI, via the usual config gem
      # override naming convention, e.g. SETTINGS__zip_endpoints__aws_s3_west_2__access_key_id
      expect(provider_class).to have_received(:new).with(region: region,
                                                         access_key_id: Settings.zip_endpoints[endpoint_name].access_key_id,
                                                         secret_access_key: Settings.zip_endpoints[endpoint_name].secret_access_key)
    end
  end

  context 'all parts listed as ok, but no parts exist on s3' do
    before do
      args = attributes_for(:zip_part)
      zmv.zip_parts.create!(
        [
          args.merge(status: 'ok', parts_count: 3, suffix: '.zip'),
          args.merge(status: 'ok', parts_count: 3, suffix: '.z01'),
          args.merge(status: 'ok', parts_count: 3, suffix: '.z02')
        ]
      )

      # fine to assume non-existence (and thus checksum irrelevance) for all parts for this test case
      allow(bucket).to receive(:object).and_return(
        instance_double(Aws::S3::Object, exists?: false)
      )
    end

    it 'logs the missing parts and sets status to not_found' do
      described_class.check_replicated_zipped_moab_version(zmv, results)
      zmv.zip_parts.each do |part|
        msg = "replicated part not found on #{endpoint_name}: #{part.s3_key} was not found on #{bucket_name}"
        expect(results.results).to include(
          a_hash_including(Audit::Results::ZIP_PART_NOT_FOUND => msg)
        )
        expect(part.status).to eq('not_found')
      end
    end
  end

  context 'all parts exist on s3' do
    before do
      args = attributes_for(:zip_part)
      zmv.zip_parts.create!(
        [
          args.merge(status: 'ok', parts_count: 3, suffix: '.zip'),
          args.merge(status: 'ok', parts_count: 3, suffix: '.z01'),
          args.merge(status: 'ok', parts_count: 3, suffix: '.z02')
        ]
      )

      zmv.zip_parts.each_with_index do |part, idx|
        allow(bucket).to receive(:object).with(part.s3_key).and_return(
          instance_double(Aws::S3::Object, exists?: true, metadata: { 'checksum_md5' => replicated_checksums[idx] })
        )
      end
    end

    context 'all checksums match' do
      let(:replicated_checksums) do
        [matching_md5, matching_md5, matching_md5]
      end

      it "doesn't log checksum mismatches" do
        described_class.check_replicated_zipped_moab_version(zmv, results)
        expect(results.results).not_to include(a_hash_including(Audit::Results::ZIP_PART_CHECKSUM_MISMATCH))
      end

      it "doesn't log not found errors" do
        described_class.check_replicated_zipped_moab_version(zmv, results)
        expect(results.results).not_to include(a_hash_including(Audit::Results::ZIP_PART_NOT_FOUND))
      end

      it 'updates existence check timestamps' do
        expect { described_class.check_replicated_zipped_moab_version(zmv, results) }
          .to change { zmv.zip_parts.first.reload.last_existence_check }
          .from(nil)
          .and change { zmv.zip_parts.second.reload.last_existence_check }
          .from(nil)
          .and change { zmv.zip_parts.third.reload.last_existence_check }
          .from(nil)
      end

      it 'updates checksum validation timestamps' do
        expect { described_class.check_replicated_zipped_moab_version(zmv, results) }
          .to change { zmv.zip_parts.first.reload.last_checksum_validation }
          .from(nil)
          .and change { zmv.zip_parts.second.reload.last_checksum_validation }
          .from(nil)
          .and change { zmv.zip_parts.third.reload.last_checksum_validation }
          .from(nil)
      end
    end

    context 'not all checksums match' do
      let(:replicated_checksums) do
        [non_matching_md5, non_matching_md5, matching_md5]
      end

      it 'logs the mismatches' do
        described_class.check_replicated_zipped_moab_version(zmv, results)
        zmv.zip_parts.where(suffix: ['.zip', '.z01']).find_each do |part|
          msg = "replicated md5 mismatch on #{endpoint_name}: #{part.s3_key} catalog md5 (#{part.md5}) " \
                "doesn't match the replicated md5 (#{non_matching_md5}) on #{bucket_name}"
          expect(results.results).to include(a_hash_including(Audit::Results::ZIP_PART_CHECKSUM_MISMATCH => msg))
        end
      end

      it 'updates existence check timestamps' do
        expect { described_class.check_replicated_zipped_moab_version(zmv, results) }
          .to change { zmv.zip_parts.first.reload.last_existence_check }
          .from(nil)
          .and change { zmv.zip_parts.second.reload.last_existence_check }
          .from(nil)
          .and change { zmv.zip_parts.third.reload.last_existence_check }
          .from(nil)
      end

      it 'updates validation timestamps' do
        expect { described_class.check_replicated_zipped_moab_version(zmv, results) }
          .to change { zmv.zip_parts.first.reload.last_checksum_validation }
          .from(nil)
          .and change { zmv.zip_parts.second.reload.last_checksum_validation }
          .from(nil)
          .and change { zmv.zip_parts.third.reload.last_checksum_validation }
          .from(nil)
      end

      it 'updates status to replicated_checksum_mismatch' do
        expect { described_class.check_replicated_zipped_moab_version(zmv, results) }
          .to change { zmv.zip_parts.first.reload.status }
          .to('replicated_checksum_mismatch')
          .and change { zmv.zip_parts.second.reload.status }
          .to('replicated_checksum_mismatch')
        expect { described_class.check_replicated_zipped_moab_version(zmv, results) }
          .not_to(change { zmv.zip_parts.third.reload.status })
      end
    end
  end

  context 'not all parts exist on s3' do
    before do
      args = attributes_for(:zip_part)
      zmv.zip_parts.create!(
        [
          args.merge(status: 'ok', parts_count: 4, suffix: '.zip'),
          args.merge(status: 'ok', parts_count: 4, suffix: '.z01'),
          args.merge(status: 'ok', parts_count: 4, suffix: '.z02'),
          args.merge(status: 'ok', parts_count: 4, suffix: '.z03')
        ]
      )

      allow(bucket).to receive(:object).with(zmv.zip_parts.first.s3_key).and_return(
        instance_double(Aws::S3::Object, exists?: false)
      )
      allow(bucket).to receive(:object).with(zmv.zip_parts.second.s3_key).and_return(
        instance_double(Aws::S3::Object, exists?: true, metadata: { 'checksum_md5' => replicated_checksums.second })
      )
      allow(bucket).to receive(:object).with(zmv.zip_parts.third.s3_key).and_return(
        instance_double(Aws::S3::Object, exists?: true, metadata: { 'checksum_md5' => replicated_checksums.third })
      )
      allow(bucket).to receive(:object).with(zmv.zip_parts.fourth.s3_key).and_return(
        instance_double(Aws::S3::Object, exists?: false)
      )
    end

    context 'all parts that do exist have matching checksums' do
      let(:replicated_checksums) do
        [matching_md5, matching_md5, matching_md5, matching_md5]
      end

      it 'logs the missing parts' do
        described_class.check_replicated_zipped_moab_version(zmv, results)

        [zmv.zip_parts.first, zmv.zip_parts.fourth].each do |part|
          msg = "replicated part not found on #{endpoint_name}: #{part.s3_key} was not found on #{bucket_name}"
          expect(results.results).to include(a_hash_including(Audit::Results::ZIP_PART_NOT_FOUND => msg))
        end
      end

      it "doesn't log checksum mismatches" do
        described_class.check_replicated_zipped_moab_version(zmv, results)
        expect(results.results).not_to include(a_hash_including(Audit::Results::ZIP_PART_CHECKSUM_MISMATCH))
      end
    end

    context 'some parts that do exist have checksums that do not match' do
      let(:replicated_checksums) do
        [non_matching_md5, non_matching_md5, matching_md5, matching_md5]
      end

      it 'logs the missing parts' do
        described_class.check_replicated_zipped_moab_version(zmv, results)
        [zmv.zip_parts.first, zmv.zip_parts.fourth].each do |part|
          msg = "replicated part not found on #{endpoint_name}: #{part.s3_key} was not found on #{bucket_name}"
          expect(results.results).to include(a_hash_including(Audit::Results::ZIP_PART_NOT_FOUND => msg))
        end
      end

      it 'logs the checksum mismatches' do
        part = zmv.zip_parts.second
        msg = "replicated md5 mismatch on #{endpoint_name}: #{part.s3_key} catalog md5 (#{part.md5}) " \
              "doesn't match the replicated md5 (#{non_matching_md5}) on #{bucket_name}"
        described_class.check_replicated_zipped_moab_version(zmv, results)
        expect(results.results).to include(a_hash_including(Audit::Results::ZIP_PART_CHECKSUM_MISMATCH => msg))
      end
    end
  end
end
