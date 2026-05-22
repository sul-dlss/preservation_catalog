# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::ReplicatedMoabChecksumValidator do
  # single-part: 1 ZMV with 1 ZipPart → part count equals ZMV count
  let!(:single_part_po) { create(:preserved_object, druid: 'bc123df4567') }
  let!(:single_part_zmv) { create(:zipped_moab_version, preserved_object: single_part_po) }
  let!(:single_part_zip_part) { create(:zip_part, zipped_moab_version: single_part_zmv, suffix: '.zip') } # rubocop:disable RSpec/LetSetup

  # multi-part: 1 ZMV with 2 ZipParts → part count exceeds ZMV count
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

  describe '#validate_replicated_moab_checksums!' do
    # rubocop:disable RSpec/BeforeAfterAll, RSpec/InstanceVariable
    before(:all) do
      @tmp_fixity_dir = Pathname(Dir.mktmpdir)
      target_dir = @tmp_fixity_dir.join('aws_s3_west_2', 'bz/514/sm/9647')
      FileUtils.mkdir_p(target_dir)
      fixture_dir = Rails.root.join('spec/fixtures/storage_root01/sdr2objects/bz/514/sm/9647')
      [1, 2, 3].each do |v|
        vstr = format('v%04d', v)
        system("cd #{fixture_dir} && zip -r #{target_dir}/bz514sm9647.#{vstr}.zip bz514sm9647/#{vstr} > /dev/null", exception: true)
      end
    end

    after(:all) { FileUtils.rm_rf(@tmp_fixity_dir) }

    let(:endpoint) { ZipEndpoint.find_by!(endpoint_name: 'aws_s3_west_2') }
    let!(:po)    { create(:preserved_object, druid: 'bz514sm9647', current_version: 3) }
    let!(:zmv1)  { create(:zipped_moab_version, preserved_object: po, zip_endpoint: endpoint, version: 1) }
    let!(:zmv2)  { create(:zipped_moab_version, preserved_object: po, zip_endpoint: endpoint, version: 2) }
    let!(:zmv3)  { create(:zipped_moab_version, preserved_object: po, zip_endpoint: endpoint, version: 3) }
    let!(:zp1)   { create(:zip_part, zipped_moab_version: zmv1, suffix: '.zip') } # rubocop:disable RSpec/LetSetup
    let!(:zp2)   { create(:zip_part, zipped_moab_version: zmv2, suffix: '.zip') } # rubocop:disable RSpec/LetSetup
    let!(:zp3)   { create(:zip_part, zipped_moab_version: zmv3, suffix: '.zip') } # rubocop:disable RSpec/LetSetup

    let(:mock_s3_object) { instance_double(Aws::S3::Object, exists?: true, metadata: {}) }
    let(:mock_bucket)    { instance_double(Aws::S3::Bucket, object: mock_s3_object, name: 'test-bucket') }
    let(:mock_provider)  { instance_double(Replication::CloudProvider, bucket: mock_bucket) }
    let(:validator) do
      described_class.new(fixity_check_base_location: @tmp_fixity_dir, dry_run: false, force_part_md5_comparison: false)
    end
    # rubocop:enable RSpec/BeforeAfterAll, RSpec/InstanceVariable

    before { allow(Replication::ProviderFactory).to receive(:create).and_return(mock_provider) }

    it 'returns results with no errors for a valid moab' do
      results = validator.validate_replicated_moab_checksums!(
        endpoints_to_audit: ['aws_s3_west_2'],
        druids: ['bz514sm9647']
      )
      expect(results).not_to be_empty
      expect(results.flat_map(&:error_results)).to be_empty
    end
  end
end
