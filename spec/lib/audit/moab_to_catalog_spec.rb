require 'rails_helper'
require_relative "../../../lib/audit/moab_to_catalog.rb"

RSpec.describe MoabToCatalog do
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' }

  before do
    PreservationPolicy.seed_from_config
  end

  describe "#seed_from_disk" do
    let(:m2c) { described_class.new }

    it 'calls seed_catalog once per storage root' do
      expect(described_class).to receive(:seed_catalog).exactly(Settings.moab.storage_roots.count).times
      m2c.seed_from_disk
    end

    it 'calls seed_catalog with the right arguments' do
      Settings.moab.storage_roots.each do |storage_root|
        expect(described_class).to receive(:seed_catalog).with("#{storage_root[1]}/#{Settings.moab.storage_trunk}")
      end
      m2c.seed_from_disk
    end
  end

  describe ".check_existence" do
    let(:subject) { described_class.check_existence(storage_dir, true) }

    it "calls 'find_moab_paths' with appropriate argument" do
      expect(Stanford::MoabStorageDirectory).to receive(:find_moab_paths).with(storage_dir)
      subject
    end

    it 'gets moab current version from Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(moab).to receive(:storage_root=)
      allow(moab).to receive(:object_pathname).and_return(storage_dir)
      allow(moab).to receive(:size)
      expect(moab).to receive(:current_version_id).at_least(1).times
      allow(Moab::StorageObject).to receive(:new).and_return(moab)

      expect(Moab::StorageServices).not_to receive(:new)
      subject
    end

    it 'gets moab size from Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(moab).to receive(:storage_root=)
      allow(moab).to receive(:object_pathname).and_return(storage_dir)
      allow(moab).to receive(:current_version_id)
      expect(moab).to receive(:size).at_least(1).times
      allow(Moab::StorageObject).to receive(:new).and_return(moab)

      expect(Moab::StorageServices).not_to receive(:new)
      subject
    end

    context "(calls create or confirm_version)" do
      let(:expected_argument_list) do
        [
          { druid: 'bj102hs9687', storage_root_current_version: 3 },
          { druid: 'bz514sm9647', storage_root_current_version: 3 },
          { druid: 'jj925bx9565', storage_root_current_version: 2 }
        ]
      end

      before do
        expected_argument_list.each do |arg_hash|
          po_handler = instance_double('PreservedObjectHandler')
          arg_hash[:po_handler] = po_handler
          allow(PreservedObjectHandler).to receive(:new).with(
            arg_hash[:druid],
            arg_hash[:storage_root_current_version],
            instance_of(Integer),
            storage_dir
          ).and_return(po_handler)
        end
      end

      context 'object does not exist' do
        it 'calls #create when expect_to_create is true' do
          expected_argument_list.each do |arg_hash|
            expect(PreservedObject).to receive(:exists?).with(druid: arg_hash[:druid]).and_return(false)
            exp_msg = "druid: #{arg_hash[:druid]} expected to exist in catalog but was not found"
            expect(Rails.logger).to receive(:error).with(exp_msg)
            expect(arg_hash[:po_handler]).to receive(:create)
          end
          described_class.check_existence(storage_dir, true)
        end
        it 'does not call #create when expect_to_create is false' do
          expected_argument_list.each do |arg_hash|
            expect(PreservedObject).to receive(:exists?).with(druid: arg_hash[:druid]).and_return(false)
            exp_msg = "druid: #{arg_hash[:druid]} expected to exist in catalog but was not found"
            expect(Rails.logger).to receive(:error).with(exp_msg)
            expect(arg_hash[:po_handler]).not_to receive(:create)
          end
          described_class.check_existence(storage_dir) # expect_to_create is false by default
        end
      end

      it "calls #confirm_version if object exists" do
        expected_argument_list.each do |arg_hash|
          expect(PreservedObject).to receive(:exists?).with(druid: arg_hash[:druid]).and_return(true)
          expect(arg_hash[:po_handler]).to receive(:confirm_version)
        end
        subject
      end
    end

    it "return correct number of results" do
      expect(subject.count).to eq 3
    end
    it "storage directory doesn't exist (misspelling, read write permissions)" do
      expect { described_class.check_existence('spec/fixtures/moab_strge_root') }.to raise_error(
        SystemCallError, /No such file or directory/
      )
    end
    it "storage directory exists but it is empty" do
      storage_dir = 'spec/fixtures/empty'
      expect(described_class.check_existence(storage_dir)).to eq []
    end
  end

  describe ".seed_catalog" do
    let(:subject) { described_class.seed_catalog(storage_dir) }

    it "calls 'find_moab_paths' with appropriate argument" do
      expect(Stanford::MoabStorageDirectory).to receive(:find_moab_paths).with(storage_dir)
      subject
    end

    it 'gets moab current version from Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(moab).to receive(:storage_root=)
      allow(moab).to receive(:object_pathname).and_return(storage_dir)
      allow(moab).to receive(:size)
      expect(moab).to receive(:current_version_id).at_least(1).times
      allow(Moab::StorageObject).to receive(:new).and_return(moab)

      expect(Moab::StorageServices).not_to receive(:new)
      subject
    end

    it 'gets moab size from Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(moab).to receive(:storage_root=)
      allow(moab).to receive(:object_pathname).and_return(storage_dir)
      allow(moab).to receive(:current_version_id)
      expect(moab).to receive(:size).at_least(1).times
      allow(Moab::StorageObject).to receive(:new).and_return(moab)

      expect(Moab::StorageServices).not_to receive(:new)
      subject
    end

    context "(creates or errors)" do
      let(:expected_argument_list) do
        [
          { druid: 'bj102hs9687', storage_root_current_version: 3 },
          { druid: 'bz514sm9647', storage_root_current_version: 3 },
          { druid: 'jj925bx9565', storage_root_current_version: 2 }
        ]
      end

      before do
        expected_argument_list.each do |arg_hash|
          po_handler = instance_double('PreservedObjectHandler')
          arg_hash[:po_handler] = po_handler
          allow(PreservedObjectHandler).to receive(:new).with(
            arg_hash[:druid],
            arg_hash[:storage_root_current_version],
            instance_of(Integer),
            storage_dir
          ).and_return(po_handler)
        end
      end
      it "call #create if object does not exist" do
        expected_argument_list.each do |arg_hash|
          expect(PreservedObject).to receive(:exists?).with(druid: arg_hash[:druid]).and_return(false)
          expect(arg_hash[:po_handler]).to receive(:create)
        end
        subject
      end
      it "error if object exists" do
        expected_argument_list.each do |arg_hash|
          allow(PreservedObject).to receive(:exists?).with(druid: arg_hash[:druid]).and_return(true)
          exp_msg = "druid: #{arg_hash[:druid]} NOT expected to exist in catalog but was found"
          expect(Rails.logger).to receive(:error).with(exp_msg)
          expect(arg_hash[:po_handler]).not_to receive(:create)
        end
        subject
      end
    end

    it "return correct number of results" do
      expect(subject.count).to eq 3
    end
    it "storage directory doesn't exist (misspelling, read write permissions)" do
      expect { described_class.check_existence('spec/fixtures/moab_strge_root') }.to raise_error(
        SystemCallError, /No such file or directory/
      )
    end
    it "storage directory exists but it is empty" do
      storage_dir = 'spec/fixtures/empty'
      expect(described_class.check_existence(storage_dir)).to eq []
    end
  end
end
