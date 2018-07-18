require 'rails_helper'

RSpec.describe PreservationCatalog::S3::Audit do
  let(:zmv) { create(:zipped_moab_version) }
  let(:bucket) { instance_double(Aws::S3::Bucket) }
  let(:bucket_name) { "sul-sdr-us-west-bucket" }
  let(:logger) { instance_double(Logger) }
  let(:matching_md5) { attributes_for(:zip_part)[:md5] }
  let(:non_matching_md5) { "asdfasdfb43t347l;x5px54xx6549;f4" }

  before do
    allow(PreservationCatalog::S3).to receive(:bucket).and_return(bucket)
    allow(PreservationCatalog::S3).to receive(:bucket_name).and_return(bucket_name)
    allow(described_class).to receive(:logger).and_return(logger)
    allow(logger).to receive(:error) # most test cases only care about a subset of the logged errors
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
      ok_part = zmv.zip_parts.find_by(suffix: '.z01')
      s3_obj = instance_double(Aws::S3::Object, exists?: true)

      expect(bucket).to receive(:object).with(ok_part.s3_key).and_return(s3_obj)
      expect(s3_obj).to receive(:metadata).and_return('checksum_md5' => ok_part.md5)
      expect { described_class.check_aws_replicated_zipped_moab_version(zmv) }
        .to change { ok_part.reload.last_existence_check }.from(nil)
        .and change { ok_part.reload.last_checksum_validation }.from(nil)
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

    it 'logs the missing parts' do
      zmv.zip_parts.each do |part|
        exp_err_msg = "Archival Preserved Copy: #{zmv.inspect} #{part.inspect} was not found on #{bucket_name}."
        expect(logger).to receive(:error).with(exp_err_msg)
      end
      described_class.check_aws_replicated_zipped_moab_version(zmv)
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
        expect(logger).not_to receive(:error).with(/doesn't match the replicated checksum/)
        described_class.check_aws_replicated_zipped_moab_version(zmv)
      end

      it "doesn't log not found errors" do
        expect(logger).not_to receive(:error).with(/Archival Preserved Copy.*was not found on/)
        described_class.check_aws_replicated_zipped_moab_version(zmv)
      end

      it 'updates existence check timestamps' do
        expect { described_class.check_aws_replicated_zipped_moab_version(zmv) }
          .to change { zmv.zip_parts.first.reload.last_existence_check }.from(nil)
          .and change { zmv.zip_parts.second.reload.last_existence_check }.from(nil)
          .and change { zmv.zip_parts.third.reload.last_existence_check }.from(nil)
      end

      it 'updates checksum validation timestamps' do
        expect { described_class.check_aws_replicated_zipped_moab_version(zmv) }
          .to change { zmv.zip_parts.first.reload.last_checksum_validation }.from(nil)
          .and change { zmv.zip_parts.second.reload.last_checksum_validation }.from(nil)
          .and change { zmv.zip_parts.third.reload.last_checksum_validation }.from(nil)
      end
    end

    context 'not all checksums match' do
      let(:replicated_checksums) do
        [non_matching_md5, non_matching_md5, matching_md5]
      end

      it 'logs the mismatches' do
        zmv.zip_parts.where(suffix: ['.zip', '.z01']).each do |part|
          msg = "Stored checksum(#{part.md5}) doesn't match the replicated checksum(#{non_matching_md5})."
          expect(logger).to receive(:error).with(msg)
        end
        described_class.check_aws_replicated_zipped_moab_version(zmv)
      end

      it 'updates existence check timestamps' do
        expect { described_class.check_aws_replicated_zipped_moab_version(zmv) }
          .to change { zmv.zip_parts.first.reload.last_existence_check }.from(nil)
          .and change { zmv.zip_parts.second.reload.last_existence_check }.from(nil)
          .and change { zmv.zip_parts.third.reload.last_existence_check }.from(nil)
      end

      it 'updates validation timestamps' do
        expect { described_class.check_aws_replicated_zipped_moab_version(zmv) }
          .to change { zmv.zip_parts.first.reload.last_checksum_validation }.from(nil)
          .and change { zmv.zip_parts.second.reload.last_checksum_validation }.from(nil)
          .and change { zmv.zip_parts.third.reload.last_checksum_validation }.from(nil)
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
        [zmv.zip_parts.first, zmv.zip_parts.fourth].each do |part|
          exp_err_msg = "Archival Preserved Copy: #{zmv.inspect} #{part.inspect} was not found on #{bucket_name}."
          expect(logger).to receive(:error).with(exp_err_msg)
        end
        described_class.check_aws_replicated_zipped_moab_version(zmv)
      end

      it "doesn't log checksum mismatches" do
        expect(logger).not_to receive(:error).with(/doesn't match the replicated checksum/)
        described_class.check_aws_replicated_zipped_moab_version(zmv)
      end
    end

    context 'some parts that do exist have checksums that do not match' do
      let(:replicated_checksums) do
        [non_matching_md5, non_matching_md5, matching_md5, matching_md5]
      end

      it 'logs the missing parts' do
        [zmv.zip_parts.first, zmv.zip_parts.fourth].each do |part|
          exp_err_msg = "Archival Preserved Copy: #{zmv.inspect} #{part.inspect} was not found on #{bucket_name}."
          expect(logger).to receive(:error).with(exp_err_msg)
        end
        described_class.check_aws_replicated_zipped_moab_version(zmv)
      end

      it 'logs the checksum mismatches' do
        expect(logger).to receive(:error).with(
          "Stored checksum(#{zmv.zip_parts.second.md5}) doesn't match the replicated checksum(#{non_matching_md5})."
        )
        described_class.check_aws_replicated_zipped_moab_version(zmv)
      end
    end
  end
end
