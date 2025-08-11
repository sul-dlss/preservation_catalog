# frozen_string_literal: true

require 'rails_helper'

describe Replication::ZipmakerJob do
  let(:druid) { 'bj102hs9687' }
  let(:dvz_part) { instance_double(Replication::DruidVersionZipPart, metadata: { fake: 1 }) }
  let(:version) { 3 }
  let(:zip_path) { "spec/fixtures/zip_storage/bj/102/hs/9687/#{druid}#{format('.v%04d.zip', version)}" }
  let(:druid_version_zip) { Replication::DruidVersionZip.new(druid, version, moab_replication_storage_location) }
  let(:moab_replication_storage_location) { 'spec/fixtures/storage_root01/sdr2objects' }

  before do
    allow(Replication::DeliveryDispatcherJob).to receive(:perform_later).with(any_args)
    allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    allow(Replication::DruidVersionZip).to receive(:new).with(druid, version, moab_replication_storage_location).and_return(druid_version_zip)
  end

  after do
    FileUtils.rm_rf(File.join(Settings.zip_storage, 'bj/102/hs/9687/bj102hs9687.v0003.zip'))
    FileUtils.rm_rf(File.join(Settings.zip_storage, 'bj/102/hs/9687/bj102hs9687.v0003.zip.md5'))
  end

  it 'invokes Replication::DeliveryDispatcherJob (single part zip)' do
    expect(Replication::DeliveryDispatcherJob).to receive(:perform_later).with(druid, version, 'bj/102/hs/9687/bj102hs9687.v0003.zip', Hash)
    described_class.perform_now(druid, version, moab_replication_storage_location)
  end

  it 'sleeps' do
    expect_any_instance_of(described_class).to receive(:sleep).with(Settings.filesystem_delay_seconds) # rubocop:disable RSpec/AnyInstance
    described_class.perform_now(druid, version, moab_replication_storage_location)
  end

  context 'the moab version to be archived is bigger than the zip split size' do
    let(:druid) { 'bz514sm9647' }
    let(:version) { 1 }

    before { stub_const('Replication::DruidVersionZip::ZIP_SPLIT_SIZE', '64k') }

    after { FileUtils.rm_rf(File.join(Settings.zip_storage, 'bz/514/sm/9647')) }

    it 'handles segmented zips, invokes Replication::DeliveryDispatcherJob per part' do
      # v1 of bz514sm9647 is 232kB, so we'd expect 4 segments if we split at 64k
      expect(Replication::DeliveryDispatcherJob).to receive(:perform_later).with(druid, version, 'bz/514/sm/9647/bz514sm9647.v0001.zip', Hash)
      expect(Replication::DeliveryDispatcherJob).to receive(:perform_later).with(druid, version, 'bz/514/sm/9647/bz514sm9647.v0001.z01', Hash)
      expect(Replication::DeliveryDispatcherJob).to receive(:perform_later).with(druid, version, 'bz/514/sm/9647/bz514sm9647.v0001.z02', Hash)
      expect(Replication::DeliveryDispatcherJob).to receive(:perform_later).with(druid, version, 'bz/514/sm/9647/bz514sm9647.v0001.z03', Hash)
      described_class.perform_now(druid, version, moab_replication_storage_location)
    end
  end

  context 'a reasonably sized zip already exists in zip storage' do
    before { druid_version_zip.create_zip! }

    it 'does not create a zip, but touches the existing one' do
      expect(File).to exist(zip_path)
      expect(druid_version_zip).not_to receive(:create_zip!)

      expect do
        described_class.perform_now(druid, version, moab_replication_storage_location)
      end.to(
        change do
          File.stat(druid_version_zip.file_path).atime
        end
          .and(change { File.stat(druid_version_zip.file_path).mtime })
      )
    end
  end

  context 'a supsiciously small zip already exists in storage' do
    let(:version) { 1 }

    it 'raises an informative error' do
      expect(File).to exist(zip_path)
      expect(druid_version_zip).not_to receive(:create_zip!)

      expect do
        described_class.perform_now(druid, version, moab_replication_storage_location)
      end.to raise_error(RuntimeError, 'zip already exists, but size (3) is smaller than the moab version size (1928387)!')
    end
  end

  context 'zip is not yet in zip storage' do
    let(:version) { 3 }

    before { allow(Replication::DruidVersionZipPart).to receive(:new).and_return(dvz_part) }

    it 'creates the zip' do
      expect(File).not_to exist(zip_path)
      expect(druid_version_zip).to receive(:create_zip!)
      described_class.perform_now(druid, version, moab_replication_storage_location)
    end
  end
end
