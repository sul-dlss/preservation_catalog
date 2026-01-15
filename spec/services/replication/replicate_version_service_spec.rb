# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/SubjectStub
RSpec.describe Replication::ReplicateVersionService do
  subject(:service) { described_class.new(preserved_object:, version:) }

  let(:preserved_object) { create(:preserved_object, druid:) }
  let(:version) { 2 }
  let(:druid) { 'bj102hs9687' }
  let(:s3_key) { 'bj/102/hs/9687/bj102hs9687.v0002.zip' }

  let(:bucket) { instance_double(Aws::S3::Bucket, object: s3_part) }
  let(:s3_part) { instance_double(Aws::S3::Object) }
  let(:provider) { instance_double(Replication::AwsProvider, bucket:) }

  let(:druid_version_zip) { instance_double(Replication::DruidVersionZip, s3_key:, complete?: true, cleanup_zip_parts!: nil) }
  let(:druid_version_zip_part) { instance_double(Replication::DruidVersionZipPart) }

  before do
    allow(Replication::DruidVersionZip).to receive(:new).with(druid, version, nil).and_return(druid_version_zip)
    allow(Replication::DruidVersionZipPart).to receive(:new).with(druid_version_zip, s3_key).and_return(druid_version_zip_part)

    allow(Replication::ProviderFactory).to receive(:create).and_return(provider)
    allow(ResultsReporter).to receive(:report_results)
  end

  context 'when there are no created or incomplete ZippedMoabVersions' do
    before do
      create(:zipped_moab_version, status: :ok, preserved_object:, version:)
      create(:zipped_moab_version, status: :failed, preserved_object:, version:)
      allow(service).to receive(:create_zip_if_necessary) # rubocop:disable RSpec/SubjectStub
    end

    it 'does nothing' do
      described_class.call(preserved_object:, version:)
      expect(service).not_to have_received(:create_zip_if_necessary) # rubocop:disable RSpec/SubjectStub
    end
  end

  context 'when zip parts files are not complete' do
    let(:druid_version_zip) { instance_double(Replication::DruidVersionZip, complete?: false, cleanup_zip_parts!: nil, create_zip!: nil) }

    before do
      create(:zipped_moab_version, status: :incomplete, preserved_object:, version:)
      # This stubs out the other parts that are not being tested here.
      allow(subject).to receive_messages(no_zip_parts_on_endpoint?: false, check_zip_parts_to_zip_file: nil)
      allow(subject).to receive(:replicate_incomplete_zipped_moab_versions)

      allow(Replication::DruidVersionZip).to receive(:new).and_return(druid_version_zip)
    end

    it 'creates the zip part files' do
      service.call
      expect(druid_version_zip).to have_received(:cleanup_zip_parts!).twice
      expect(druid_version_zip).to have_received(:create_zip!)
    end
  end

  context 'when no zip parts are found on the endpoint for an incomplete ZippedMoabVersion' do
    let!(:zipped_moab_version) do
      create(:zipped_moab_version, status: :incomplete, preserved_object:, version:).tap do |zipped_moab_version|
        create(:zip_part, zipped_moab_version:)
      end
    end

    before do
      allow(subject).to receive(:check_zip_parts_to_zip_file).and_return(nil)
      allow(subject).to receive(:populate_zip_parts!)
      allow(subject).to receive(:replicate_incomplete_zipped_moab_versions)

      allow(s3_part).to receive(:exists?).and_return(false)
    end

    it 'resets the ZippedMoabVersion to created status and deletes any existing ZipParts' do
      expect { service.call }
        .to change { zipped_moab_version.reload.status }.from('incomplete').to('created')
        .and change(zipped_moab_version, :status_details).from(nil).to('no zip part files found on endpoint')
        .and change { zipped_moab_version.zip_parts.count }.from(1).to(0)
    end
  end

  context 'when there is a md5 mismatch for a zip part file' do
    let!(:zipped_moab_version) do
      create(:zipped_moab_version, status: :incomplete, preserved_object:, version:).tap do |zipped_moab_version|
        create(:zip_part, zipped_moab_version:)
      end
    end

    let(:results) { instance_double(Results, empty?: false, to_s: 'md5 mismatch for zip part sidecar file') }

    before do
      # This stubs out the other parts that are not being tested here.
      allow(subject).to receive(:no_zip_parts_on_endpoint?).and_return(false)
      allow(subject).to receive(:replicate_incomplete_zipped_moab_versions)
      allow(Replication::ZipPartsToZipFilesAuditService).to receive(:call).with(zipped_moab_version:).and_return(results)
    end

    it 'sets the ZippedMoabVersion status to failed' do
      expect { service.call }
        .to change { zipped_moab_version.reload.status }.from('incomplete').to('failed')
        .and change(zipped_moab_version, :status_details).to('md5 mismatch for zip part sidecar file')
      expect(ResultsReporter).to have_received(:report_results).with(results:)
    end
  end

  context 'when there are created ZippedMoabVersions' do
    let!(:zipped_moab_version) do
      create(:zipped_moab_version, status: :created, preserved_object:, version:)
    end

    let(:druid_version_zip_part1) { instance_double(Replication::DruidVersionZipPart, extname: '.zip', read_md5: '00236a2ae558018ed13b5222ef1bd977', size: 1234) }
    let(:druid_version_zip_part2) { instance_double(Replication::DruidVersionZipPart, extname: '.z02', read_md5: '11236a2ae558018ed13b5222ef1bd988', size: 5678) }

    before do
      # This stubs out the other parts that are not being tested here.
      allow(subject).to receive(:replicate_incomplete_zipped_moab_versions)

      allow(druid_version_zip).to receive(:druid_version_zip_parts).and_return([druid_version_zip_part1, druid_version_zip_part2])
    end

    it 'populates the ZipParts for the ZippedMoabVersion' do
      expect { service.call }
        .to change { zipped_moab_version.zip_parts.count }.from(0).to(2)
        .and change { zipped_moab_version.reload.status }.from('created').to('incomplete')
        .and change(zipped_moab_version, :zip_parts_count).from(nil).to(2)
      zip_part1 = zipped_moab_version.zip_parts.find_by(suffix: '.zip')
      expect(zip_part1.size).to eq 1234
      expect(zip_part1.md5).to eq '00236a2ae558018ed13b5222ef1bd977'
      zip_part2 = zipped_moab_version.zip_parts.find_by(suffix: '.z02')
      expect(zip_part2.size).to eq 5678
      expect(zip_part2.md5).to eq '11236a2ae558018ed13b5222ef1bd988'
    end
  end

  context 'when replication succeeds' do
    let(:zipped_moab_version) do
      create(:zipped_moab_version, status: :incomplete, preserved_object:, version:)
    end
    let!(:zip_part) { create(:zip_part, zipped_moab_version:) }
    let(:results) { instance_double(Results, empty?: true) }

    before do
      # This stubs out the other parts that are not being tested here.
      allow(subject).to receive(:create_zip_if_necessary)
      allow(subject).to receive_messages(no_zip_parts_on_endpoint?: false, check_zip_parts_to_zip_file: nil)

      allow(Replication::ReplicateZipPartService).to receive(:call).and_return(results)
      allow(Dor::Event::Client).to receive(:create)
      allow(Socket).to receive(:gethostname).and_return('fakehost')
    end

    it 'sets the ZippedMoabVersion status to ok and sends a DSA event' do
      expect { service.call }.to change { zipped_moab_version.reload.status }.from('incomplete').to('ok')
      expect(Replication::ReplicateZipPartService).to have_received(:call).with(zip_part:).once

      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'druid_version_replicated',
        data: hash_including(
          host: 'fakehost',
          invoked_by: 'preservation-catalog',
          version:,
          endpoint_name: zipped_moab_version.zip_endpoint.endpoint_name,
          parts_info: [{ s3_key:, size: 1234, md5: '00236a2ae558018ed13b5222ef1bd977' }]
        )
      )

      expect(druid_version_zip).to have_received(:cleanup_zip_parts!)
    end
  end

  context 'when replication encounters an existing zip part file with an md5 mismatch' do
    let!(:zipped_moab_version) do
      create(:zipped_moab_version, status: :incomplete, preserved_object:, version:).tap do |zipped_moab_version|
        create_list(:zip_part, 2, zipped_moab_version:)
      end
    end
    let(:results) { instance_double(Results, empty?: true) }
    let(:error_results) { instance_double(Results, empty?: false, to_s: 'some error message') }

    before do
      # This stubs out the other parts that are not being tested here.
      allow(subject).to receive(:create_zip_if_necessary)
      allow(subject).to receive_messages(no_zip_parts_on_endpoint?: false, check_zip_parts_to_zip_file: nil)

      allow(Replication::ReplicateZipPartService).to receive(:call).and_return(results, error_results)
    end

    it 'sets the ZippedMoabVersion status to failed and notifies' do
      expect { service.call }
        .to change { zipped_moab_version.reload.status }.from('incomplete').to('failed')
        .and change(zipped_moab_version, :status_details).to('some error message')
      expect(ResultsReporter).to have_received(:report_results).with(results: error_results)
      expect(druid_version_zip).to have_received(:cleanup_zip_parts!)
    end
  end
end
# rubocop:enable RSpec/SubjectStub
