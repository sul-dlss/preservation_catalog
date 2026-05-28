# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::ReplicatedMoabChecksumValidator do
  let!(:single_part_po) { create(:preserved_object, druid: 'bc123df4567') }
  let!(:single_part_zmv) { create(:zipped_moab_version, preserved_object: single_part_po) }
  let!(:single_part_zip_part) { create(:zip_part, zipped_moab_version: single_part_zmv, suffix: '.zip') } # rubocop:disable RSpec/LetSetup

  let!(:multi_part_po) { create(:preserved_object, druid: 'gh456jk8901') }
  let!(:multi_part_zmv) { create(:zipped_moab_version, preserved_object: multi_part_po) }
  let!(:multi_part_zip_part1) { create(:zip_part, zipped_moab_version: multi_part_zmv, suffix: '.zip') } # rubocop:disable RSpec/LetSetup
  let!(:multi_part_zip_part2) { create(:zip_part, zipped_moab_version: multi_part_zmv, suffix: '.z01') } # rubocop:disable RSpec/LetSetup

  describe '.druids_having_single_part_versions' do
    it 'returns druids whose every ZMV has exactly one zip part, not druids with any multi-part ZMV' do
      result = described_class.druids_having_single_part_versions(10)
      expect(result).to include(single_part_po.druid)
      expect(result).not_to include(multi_part_po.druid)
    end
  end

  describe '.druids_having_a_multi_part_version' do
    it 'returns druids with at least one multi-part ZMV, not druids where all ZMVs are single-part' do
      result = described_class.druids_having_a_multi_part_version(10)
      expect(result).to include(multi_part_po.druid)
      expect(result).not_to include(single_part_po.druid)
    end
  end

  describe '#validate_replicated_moab_checksums!' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:fixture_dir) { Rails.root.join('spec/fixtures/storage_root01/sdr2objects/bz/514/sm/9647') }
    let(:fixity_check_base_location) { Pathname(Dir.mktmpdir) }
    let(:zip_endpoint) { ZipEndpoint.find_by!(endpoint_name: 'aws_s3_west_2') }
    let!(:po) { create(:preserved_object, druid: 'bz514sm9647', current_version: 3) }
    let!(:zmv1) { create(:zipped_moab_version, preserved_object: po, zip_endpoint:, version: 1) }
    let!(:zmv2) { create(:zipped_moab_version, preserved_object: po, zip_endpoint:, version: 2) }
    let!(:zmv3) { create(:zipped_moab_version, preserved_object: po, zip_endpoint:, version: 3) }
    let!(:zp1) { create(:zip_part, zipped_moab_version: zmv1, suffix: '.zip') } # rubocop:disable RSpec/LetSetup
    let!(:zp2) { create(:zip_part, zipped_moab_version: zmv2, suffix: '.zip') } # rubocop:disable RSpec/LetSetup
    let!(:zp3) { create(:zip_part, zipped_moab_version: zmv3, suffix: '.zip') } # rubocop:disable RSpec/LetSetup

    let(:mock_s3_object) { instance_double(Aws::S3::Object, exists?: true, metadata: {}) }
    let(:mock_bucket)    { instance_double(Aws::S3::Bucket, object: mock_s3_object, name: 'test-bucket') }
    let(:mock_provider)  { instance_double(Replication::CloudProvider, bucket: mock_bucket, client: instance_double(Aws::S3::Client)) }
    let(:mock_transfer_manager) { instance_double(Aws::S3::TransferManager, download_file: nil) }

    let(:zip_endpoint_dir) { fixity_check_base_location.join('aws_s3_west_2') }
    let(:druid_zip_download_dir) { zip_endpoint_dir.join('bz/514/sm/9647') }

    let(:dry_run) { false }
    let(:additional_logger) { Logger.new('log/test.log') }
    let(:validator) do
      described_class.new(fixity_check_base_location:, dry_run:, force_part_md5_comparison: false, additional_logger:)
    end

    before do
      FileUtils.mkdir_p(fixity_check_base_location)
      allow(Replication::ProviderFactory).to receive(:create).and_return(mock_provider)
      allow(Aws::S3::TransferManager).to receive(:new).with(client: zip_endpoint.provider.client).and_return(mock_transfer_manager)
      allow(additional_logger).to receive(:info).and_call_original
    end

    after { FileUtils.rm_rf(fixity_check_base_location) }

    context 'the zip files were retrieved on a prior run' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      # create the zip files in their expected retrieval locations before the test, as if they were already downloaded
      # NOTE: we're not bothering to update the expected sizes or MD5 values on the zip part for this test, so the logs
      # will show errors for them.  we exercise that check in the download test.
      before do
        FileUtils.mkdir_p(druid_zip_download_dir)
        [1, 2, 3].each do |v|
          vstr = format('v%04d', v)
          zip_filename = "#{druid_zip_download_dir}/bz514sm9647.#{vstr}.zip"
          system("cd #{fixture_dir} && zip -r #{zip_filename} bz514sm9647/#{vstr} > /dev/null", exception: true)
        end
      end

      it 'returns results with no errors for a valid moab' do
        results = validator.validate_replicated_moab_checksums!(
          endpoints_to_audit: ['aws_s3_west_2'],
          druids: ['bz514sm9647']
        )
        expect(results).not_to be_empty
        expect(results.flat_map(&:error_results)).to be_empty
        expect(Aws::S3::TransferManager).not_to have_received(:new)
        expect(mock_transfer_manager).not_to have_received(:download_file)
        expect(additional_logger).to have_received(:info).with(/skipping download of.*already downloaded/).thrice
      end

      context 'the cloud archive zip is corrupted or incomplete' do # rubocop:disable RSpec/MultipleMemoizedHelpers
        # the before block from the parent context will set up the zip file fixtures.  this before block will corrupt them by
        # removing a couple of the files.
        before do
          zip_filename = "#{druid_zip_download_dir}/bz514sm9647.v0001.zip"
          internal_filepath_to_delete = 'bz514sm9647/v0001/data/content/SC1258_FUR_032a.jpg'
          system("cd #{fixture_dir} && zip -d #{zip_filename} #{internal_filepath_to_delete} > /dev/null", exception: true)

          zip_filename = "#{druid_zip_download_dir}/bz514sm9647.v0003.zip"
          internal_filepath_to_delete = 'bz514sm9647/v0003/manifests/manifestInventory.xml'
          system("cd #{fixture_dir} && zip -d #{zip_filename} #{internal_filepath_to_delete} > /dev/null", exception: true)
        end

        it 'returns and logs error results for an invalid moab' do
          results = validator.validate_replicated_moab_checksums!(
            endpoints_to_audit: ['aws_s3_west_2'],
            druids: ['bz514sm9647']
          )
          expect(additional_logger).to have_received(:info).with(
            %r{fixity check failed, investigate errors - validate_checksums - bz514sm9647 - actual location: .*/aws_s3_west_2/; actual version: 3}
          )
          expect(additional_logger).to have_received(:info).with(
            %r{manifest_not_in_moab: .*bz514sm9647/v0003/manifests/manifestInventory.xml not found in Moab}
          )
          expect(additional_logger).to have_received(:info).with(
            %r{file_not_in_moab: "#{fixity_check_base_location}/aws_s3_west_2/bz/514/sm/9647/bz514sm9647/v0003/manifests/signatureCatalog.xml refers to file \(#{fixity_check_base_location}/aws_s3_west_2/bz/514/sm/9647/bz514sm9647/v0001/data/content/SC1258_FUR_032a.jpg\) not found in Moab} # rubocop:disable Layout/LineLength
          )
          expect(additional_logger).to have_received(:info).with(
            /invalid_moab: "Invalid Moab, validation errors: \[\\"Version v0001: No files present in content dir\\", \\"Version v0003: Missing manifestInventory.xml\\"\]"/ # rubocop:disable Layout/LineLength
          )

          expect(results.first.error_results).to include(
            { manifest_not_in_moab: "#{fixity_check_base_location}/aws_s3_west_2/bz/514/sm/9647/bz514sm9647/v0003/manifests/manifestInventory.xml not found in Moab" }, # rubocop:disable Layout/LineLength
            { file_not_in_moab: "#{fixity_check_base_location}/aws_s3_west_2/bz/514/sm/9647/bz514sm9647/v0003/manifests/signatureCatalog.xml refers to file (#{fixity_check_base_location}/aws_s3_west_2/bz/514/sm/9647/bz514sm9647/v0001/data/content/SC1258_FUR_032a.jpg) not found in Moab" }, # rubocop:disable Layout/LineLength
            { invalid_moab: 'Invalid Moab, validation errors: ["Version v0001: No files present in content dir", "Version v0003: Missing manifestInventory.xml"]' } # rubocop:disable Layout/LineLength
          )
        end
      end
    end

    context 'the zip files have yet to be retrieved from endpoints' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      # * create the zip files in the root of the fixity_check_base_location, since they'll be looked
      #   for in a druid tree for the endpoint under that base location.
      # * update the zip part size and md5 info in the DB so that we can confirm those checks work.
      # * mock the download by symlinking from the expected druid tree location to the real zip file.
      before do
        FileUtils.mkdir_p(zip_endpoint_dir)

        [1, 2, 3].each do |v|
          vstr = format('v%04d', v)
          zip_filename = "bz514sm9647.#{vstr}.zip"
          concrete_zip_filepath_str = "#{fixity_check_base_location}/#{zip_filename}"

          zp = ZipPart.find_by!(zipped_moab_version: ZippedMoabVersion.where(preserved_object: po, version: v))
          system("cd #{fixture_dir} && zip -r #{concrete_zip_filepath_str} bz514sm9647/#{vstr} > /dev/null", exception: true)
          zp.update!(
            md5: Digest::MD5.file(concrete_zip_filepath_str).hexdigest,
            size: File.size(concrete_zip_filepath_str)
          )
          download_path = Pathname(druid_zip_download_dir.join(zip_filename))
          allow(mock_transfer_manager).to receive(:download_file).with(download_path, bucket: mock_bucket.name, key: zp.s3_key) do
            FileUtils.ln_s(concrete_zip_filepath_str, druid_zip_download_dir)
          end
        end
      end

      it 'returns results with no errors for a valid moab' do
        results = validator.validate_replicated_moab_checksums!(
          endpoints_to_audit: ['aws_s3_west_2'],
          druids: ['bz514sm9647']
        )
        expect(results).not_to be_empty
        expect(results.flat_map(&:error_results)).to be_empty
        expect(additional_logger).to have_received(:info).with(
          %r{downloading bz/514/sm/9647/bz514sm9647.v0003.zip from aws_s3_west_2 \(12.5 KB expected\)}
        )
        expect(additional_logger).to have_received(:info).with(
          %r{downloaded bz/514/sm/9647/bz514sm9647.v0003.zip from aws_s3_west_2 \(12.5 KB retrieved\)}
        )
        expect(additional_logger).to have_received(:info).with(
          /fresh_md5.hexdigest==db_md5: ✅/
        ).thrice
        expect(additional_logger).not_to have_received(:info).with(/already downloaded/)
        expect(additional_logger).to have_received(:info).with(
          %r{fixity check passed - validate_checksums - bz514sm9647 - actual location: #{fixity_check_base_location}/aws_s3_west_2/; actual version: 3} # rubocop:disable Layout/LineLength
        )
      end

      context 'executing a dry run' do # rubocop:disable RSpec/MultipleMemoizedHelpers
        let(:dry_run) { true }

        it 'does not attempt to download or compare, and indicates in logs that it is a dry run' do
          results = validator.validate_replicated_moab_checksums!(
            endpoints_to_audit: ['aws_s3_west_2'],
            druids: ['bz514sm9647']
          )
          expect(results).to be_empty
          expect(additional_logger).to have_received(:info).with(/=== DRY RUN ==/)
          expect(additional_logger).to have_received(:info).with(/skipping unzipping bz514sm9647.v0001.zip/)
          expect(additional_logger).to have_received(:info).with(/skipping download and fresh MD5 .*bz514sm9647.v0003.zip from aws_s3_west_2/)
          expect(Aws::S3::TransferManager).not_to have_received(:new)
          expect(mock_transfer_manager).not_to have_received(:download_file)
        end
      end
    end
  end
end
