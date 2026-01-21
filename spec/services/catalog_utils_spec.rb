# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogUtils do
  let(:storage_dir) { 'spec/fixtures/storage_root01/sdr2objects' }
  let(:ms_root) { MoabStorageRoot.find_by!(storage_location: storage_dir) }
  let(:moab) do
    moab = instance_double(Moab::StorageObject, object_pathname: storage_dir, :storage_root= => nil)
    allow(Moab::StorageObject).to receive(:new).and_return(moab)
    moab
  end
  let(:audit_workflow_reporter) { instance_double(ResultsReporters::AuditWorkflowReporter, report_errors: nil, report_completed: nil) }
  let(:event_service_reporter) { instance_double(ResultsReporters::EventServiceReporter, report_errors: nil, report_completed: nil) }
  let(:honeybadger_reporter) { instance_double(ResultsReporters::HoneybadgerReporter, report_errors: nil, report_completed: nil) }
  let(:logger_reporter) { instance_double(ResultsReporters::LoggerReporter, report_errors: nil, report_completed: nil) }
  let(:results) { instance_double(Results, to_a: results_array) }
  let(:results_array) { [] }

  before do
    allow(described_class.logger).to receive(:info) # silence STDOUT chatter
    allow(ResultsReporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(ResultsReporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
    allow(ResultsReporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(ResultsReporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
  end

  describe '.logger' do
    let(:logfile) { Rails.root.join('log', 'audit_moab_to_catalog.log') }

    after { FileUtils.rm_f(logfile) }

    it 'writes to STDOUT and its own log' do
      expect { described_class.logger.debug('foobar') }.to output(/foobar/).to_stdout_from_any_process
      expect(File).to exist(logfile)
    end
  end

  describe '.populate_catalog_for_all_storage_roots' do
    it 'calls populate_catalog_for_dir with the right argument once per root' do
      allow(described_class).to receive(:populate_catalog_for_dir).exactly(MoabStorageRoot.count).times
      MoabStorageRoot.pluck(:storage_location) do |path|
        allow(described_class).to receive(:populate_catalog_for_dir).with("#{path}/#{Settings.moab.storage_trunk}")
      end

      described_class.populate_catalog_for_all_storage_roots
      expect(described_class).to have_received(:populate_catalog_for_dir).exactly(MoabStorageRoot.count).times
      MoabStorageRoot.pluck(:storage_location) do |path|
        expect(described_class).to have_received(:populate_catalog_for_dir).with("#{path}/#{Settings.moab.storage_trunk}")
      end
    end

    it 'does not ingest more than one Moab per druid (first ingested wins)' do
      described_class.populate_catalog_for_all_storage_roots
      expect(PreservedObject.count).to eq 17
      expect(MoabRecord.count).to eq 17
      expect(MoabRecord.by_druid('bz514sm9647').count).to eq 1
      expect(MoabRecord.by_druid('bz514sm9647').take!.moab_storage_root.name).to eq 'fixture_sr1'
    end
  end

  describe '.check_existence_for_druid' do
    let(:druid) { 'bz514sm9647' }
    let(:storage_dir_a) { 'spec/fixtures/storage_rootA/sdr2objects' }
    let(:results_array) do
      [{ db_obj_does_not_exist: 'MoabRecord db object does not exist' },
       { created_new_object: 'added object to db as it did not exist' }]
    end
    let(:po) { PreservedObject.find_by!(druid: druid) }
    let(:msr) { MoabStorageRoot.find_by!(storage_location: storage_dir) }

    it 'finds and catalogs the relevant moab' do
      expect(MoabRecord.by_druid(druid).by_storage_root(msr)).not_to exist
      described_class.check_existence_for_druid(druid)
      expect(MoabRecord.by_druid(druid).by_storage_root(msr)).to exist
    end

    it 'creates the MoabRecord records, each with its respective version' do
      described_class.check_existence_for_druid(druid)
      expect(MoabRecord.find_by!(preserved_object: po, moab_storage_root: msr).version).to eq 3
    end

    it 'calls check_existence' do
      allow(MoabRecordService::CheckExistence).to receive(:execute).and_return(results)
      described_class.check_existence_for_druid(druid)
      expect(MoabRecordService::CheckExistence).to have_received(:execute).with(druid: druid,
                                                                                incoming_version: 3, # current_version
                                                                                incoming_size: instance_of(Integer), # size
                                                                                moab_storage_root: ms_root)
    end

    it 'returns results' do
      expect(described_class.check_existence_for_druid(druid)).to eq results_array
    end

    context 'given a druid that does not exist' do
      let(:druid) { 'db102hs2345' }

      it 'does not call check_existence' do
        allow(MoabRecordService::CheckExistence).to receive(:execute)
        described_class.check_existence_for_druid(druid)
        expect(MoabRecordService::CheckExistence).not_to have_received(:execute)
      end
    end
  end

  describe '.check_existence_for_druid_list' do
    let(:csv_file_path) { 'spec/fixtures/druid_list.csv' }

    before do
      CSV.foreach(csv_file_path) do |row|
        allow(described_class).to receive(:check_existence_for_druid).with(row.first)
      end
    end

    it 'calls MoabToCatalog.check_existence_for_druid once per druid' do
      described_class.check_existence_for_druid_list(csv_file_path)
      CSV.foreach(csv_file_path) do |row|
        expect(described_class).to have_received(:check_existence_for_druid).with(row.first)
      end
    end
  end

  describe '.populate_catalog_for_dir' do
    let(:storage_dir_a) { 'spec/fixtures/storage_rootA/sdr2objects' }
    let(:druid) { 'bz514sm9647' }

    it "calls 'find_moab_paths' with appropriate argument" do
      allow(MoabOnStorage::StorageDirectory).to receive(:find_moab_paths).with(storage_dir)
      described_class.populate_catalog_for_dir(storage_dir)
      expect(MoabOnStorage::StorageDirectory).to have_received(:find_moab_paths).with(storage_dir)
    end

    it 'gets moab size and current version from Moab::StorageObject' do
      allow(moab).to receive(:size).at_least(:once)
      allow(moab).to receive(:current_version_id).at_least(:once)
      allow(Moab::StorageServices).to receive(:new)
      described_class.populate_catalog_for_dir(storage_dir)
      expect(moab).to have_received(:size).at_least(:once)
      expect(moab).to have_received(:current_version_id).at_least(:once)
      expect(Moab::StorageServices).not_to have_received(:new)
    end

    context '(creates after validation)' do
      let(:expected_argument_list) do
        [
          { druid: 'bj102hs9687', storage_root_current_version: 3 },
          { druid: 'bz514sm9647', storage_root_current_version: 3 },
          { druid: 'jj925bx9565', storage_root_current_version: 2 }
        ]
      end

      before do
        allow(MoabRecordService::CreateAfterValidation).to receive(:execute).and_return(results)
      end

      it 'calls #create_after_validation' do
        described_class.populate_catalog_for_dir(storage_dir)
        expected_argument_list.each do |arg_hash|
          expect(MoabRecordService::CreateAfterValidation).to have_received(:execute).with(
            druid: arg_hash[:druid],
            incoming_version: arg_hash[:storage_root_current_version],
            incoming_size: instance_of(Integer),
            moab_storage_root: ms_root
          )
        end
      end
    end

    it 'returns correct number of results' do
      expect(described_class.populate_catalog_for_dir(storage_dir).count).to eq 3
    end

    it 'does not create a new MoabRecord for a druid that has already been cataloged' do
      expect(MoabRecord.by_druid(druid).count).to eq 0
      expect(described_class.populate_catalog_for_dir(storage_dir).count).to eq 3
      expect(MoabRecord.by_druid(druid).count).to eq 1
      expect(MoabRecord.count).to eq 3

      storage_dir_a_population_result_lists = described_class.populate_catalog_for_dir(storage_dir_a)
      expect(storage_dir_a_population_result_lists.count).to eq 1
      expected_result_msg = 'db update failed: #<ActiveRecord::RecordNotSaved: Failed to remove the existing associated moab_record. ' \
                            'The record failed to save after its foreign key was set to nil.>'
      expect(storage_dir_a_population_result_lists.first).to eq([{ db_update_failed: expected_result_msg }])
      expect(MoabRecord.by_druid(druid).count).to eq 1
      # the Moab's original location should remain the location of record in the DB
      expect(MoabRecord.by_druid(druid).take.moab_storage_root.storage_location).to eq(storage_dir)
      expect(MoabRecord.count).to eq 3
      expect(PreservedObject.count).to eq 3
    end
  end

  describe '.populate_moab_storage_root' do
    before { described_class.populate_catalog_for_all_storage_roots }

    it "doesn't change objects in a fully seeded db" do
      expect { described_class.populate_moab_storage_root('fixture_sr1') }.not_to change(MoabRecord, :count).from(17)
      expect(PreservedObject.count).to eq 17
    end

    it 're-adds objects for a dropped MoabStorageRoot' do
      ZippedMoabVersion.destroy_all
      ms_root.moab_records.destroy_all
      PreservedObject.where.missing(:moab_record).destroy_all
      expect(PreservedObject.count).to eq 14
      expect { described_class.populate_moab_storage_root('fixture_sr1') }.to change(MoabRecord, :count).from(14).to(17)
      expect(PreservedObject.count).to eq 17
    end
  end
end
