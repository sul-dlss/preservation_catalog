require_relative '../../../lib/audit/catalog_to_moab.rb'
require_relative '../../load_fixtures_helper.rb'

RSpec.describe CatalogToMoab do
  let(:last_checked_version_b4_date) { (Time.now.utc - 1.day).iso8601 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' }

  context '#initialize' do
    include_context 'fixture moabs in db'
    let(:druid) { 'bj102hs9687' }
    let(:pres_copy) do
      po = PreservedObject.find_by(druid: druid)
      ep = Endpoint.find_by(storage_location: storage_dir).id
      PreservedCopy.find_by(preserved_object: po, endpoint: ep)
    end

    it 'sets attributes' do
      c2m = described_class.new(pres_copy, storage_dir)
      expect(c2m.preserved_copy).to eq pres_copy
      expect(c2m.storage_dir).to eq storage_dir
      expect(c2m.druid).to eq druid
      expect(c2m.results).to be_an_instance_of AuditResults
    end
  end

  context '#check_catalog_version' do
    include_context 'fixture moabs in db'
    let(:druid) { 'bj102hs9687' }
    let(:pres_copy) do
      po = PreservedObject.find_by(druid: druid)
      ep = Endpoint.find_by(storage_location: storage_dir).id
      pc = PreservedCopy.find_by(preserved_object: po, endpoint: ep)
      pc.update(status: PreservedCopy::OK_STATUS)
      pc
    end
    let(:object_dir) { "#{storage_dir}/#{DruidTools::Druid.new(druid).tree.join('/')}" }
    let(:c2m) { described_class.new(pres_copy, storage_dir) }

    it 'instantiates Moab::StorageObject from druid and storage_dir' do
      expect(Moab::StorageObject).to receive(:new).with(druid, a_string_matching(object_dir)).and_call_original
      c2m.check_catalog_version
    end

    it 'gets the current version on disk from the Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject, object_pathname: object_dir)
      allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
      expect(moab).to receive(:current_version_id).and_return(3)
      c2m.check_catalog_version
    end

    it 'calls PreservedCopy.update_audit_timestamps' do
      expect(pres_copy).to receive(:update_audit_timestamps).with(anything, true)
      c2m.check_catalog_version
    end

    it 'calls PreservedCopy.save!' do
      expect(pres_copy).to receive(:save!)
      c2m.check_catalog_version
    end

    it 'calls AuditResults.report_results' do
      results = instance_double(AuditResults, add_result: nil, :actual_version= => nil, :check_name= => nil)
      allow(AuditResults).to receive(:new).and_return(results)
      expect(results).to receive(:report_results)
      c2m.check_catalog_version
    end

    it 'calls online_moab_found(druid, storage_dir)' do
      expect(c2m).to receive(:online_moab_found?).with(druid, storage_dir)
      c2m.check_catalog_version
    end

    context 'moab is nil (exists in catalog but not online)' do
      it 'adds an MOAB_NOT_FOUND result' do
        allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(nil)
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        expect(results).to receive(:add_result).with(
          AuditResults::MOAB_NOT_FOUND, db_created_at: anything, db_updated_at: anything
        )
        expect(results).to receive(:add_result).with(
          AuditResults::PC_STATUS_CHANGED, old_status: "ok", new_status: "online_moab_not_found"
        )
        c2m.check_catalog_version
      end
      context 'updates status correctly' do
        before do
          allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(nil)
        end

        [
          PreservedCopy::VALIDITY_UNKNOWN_STATUS,
          PreservedCopy::OK_STATUS,
          PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
          PreservedCopy::INVALID_MOAB_STATUS,
          PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        ].each do |orig_status|
          it "had #{orig_status}, should now have ONLINE_MOAB_NOT_FOUND_STATUS" do
            pres_copy.status = orig_status
            pres_copy.save!
            c2m.check_catalog_version
            expect(pres_copy.reload.status).to eq PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS
          end
        end
      end
      it 'stops processing .check_catalog_version' do
        moab = instance_double(Moab::StorageObject)
        allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(nil)
        expect(moab).not_to receive(:current_version_id)
        c2m.check_catalog_version
      end
    end

    context 'preserved_copy version != current_version of preserved_object' do
      it 'adds a PC_PO_VERSION_MISMATCH result and returns' do
        pres_copy.version = 666
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        expect(results).to receive(:add_result).with(
          AuditResults::PC_PO_VERSION_MISMATCH,
          pc_version: pres_copy.version,
          po_version: pres_copy.preserved_object.current_version
        )
        expect(Moab::StorageObject).not_to receive(:new).with(druid, a_string_matching(object_dir)).and_call_original
        c2m.check_catalog_version
      end
    end

    context 'catalog version == moab version (happy path)' do
      it 'adds a VERSION_MATCHES result' do
        results = instance_double(AuditResults, report_results: nil, :actual_version= => nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        expect(results).to receive(:add_result).with(AuditResults::VERSION_MATCHES, 'PreservedCopy')
        c2m.check_catalog_version
      end

      context 'check whether PreservedCopy already has a status other than OK_STATUS, re-check status if so' do
        [
          PreservedCopy::VALIDITY_UNKNOWN_STATUS,
          PreservedCopy::OK_STATUS,
          PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
          PreservedCopy::INVALID_MOAB_STATUS,
          PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        ].each do |orig_status|
          it "had #{orig_status}, should now have OK_STATUS" do
            pres_copy.status = orig_status
            pres_copy.save!
            allow(c2m).to receive(:moab_validation_errors).and_return([])
            c2m.check_catalog_version
            expect(pres_copy.reload.status).to eq PreservedCopy::OK_STATUS
          end
        end

        # PreservedCopy::OK_STATUS intentionally omitted, since we don't check status on disk
        # if versions match
        [
          PreservedCopy::VALIDITY_UNKNOWN_STATUS,
          PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
          PreservedCopy::INVALID_MOAB_STATUS,
          PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        ].each do |orig_status|
          it "had #{orig_status}, should now have INVALID_MOAB_STATUS" do
            pres_copy.status = orig_status
            pres_copy.save!
            allow(c2m).to receive(:moab_validation_errors).and_return(
              [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
            )
            c2m.check_catalog_version
            expect(pres_copy.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
          end
        end
      end
    end

    context 'catalog version < moab version' do
      before do
        moab = instance_double(Moab::StorageObject, size: 666, object_pathname: object_dir)
        allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
        allow(moab).to receive(:current_version_id).and_return(4)
      end

      it 'calls PreservedObjectHandler.update_version_after_validation' do
        pohandler = instance_double(PreservedObjectHandler)
        expect(PreservedObjectHandler).to receive(:new).and_return(pohandler)
        expect(pohandler).to receive(:update_version_after_validation)
        c2m.check_catalog_version
      end

      context 'check whether PreservedCopy already has a status other than OK_STATUS, re-check status if so' do
        [
          PreservedCopy::VALIDITY_UNKNOWN_STATUS,
          PreservedCopy::OK_STATUS,
          PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
          PreservedCopy::INVALID_MOAB_STATUS,
          PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        ].each do |orig_status|
          it "had #{orig_status}, should now have OK_STATUS" do
            pres_copy.status = orig_status
            pres_copy.save!
            mock_sov = instance_double(Stanford::StorageObjectValidator)
            allow(mock_sov).to receive(:validation_errors).and_return([])
            allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
            c2m.check_catalog_version
            expect(pres_copy.reload.status).to eq PreservedCopy::OK_STATUS
          end
        end

        [
          PreservedCopy::VALIDITY_UNKNOWN_STATUS,
          PreservedCopy::OK_STATUS,
          PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
          PreservedCopy::INVALID_MOAB_STATUS,
          PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        ].each do |orig_status|
          it "had #{orig_status}, should now have INVALID_MOAB_STATUS" do
            pres_copy.status = orig_status
            pres_copy.save!
            mock_sov = instance_double(Stanford::StorageObjectValidator)
            allow(mock_sov).to receive(:validation_errors).and_return(
              [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
            )
            allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
            c2m.check_catalog_version
            expect(pres_copy.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
          end
        end
      end
    end

    context 'catalog version > moab version' do
      before do
        moab = instance_double(Moab::StorageObject, size: 666, object_pathname: object_dir)
        allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
        allow(moab).to receive(:current_version_id).and_return(2)
      end

      it 'adds an UNEXPECTED_VERSION result' do
        results = instance_double(AuditResults, report_results: nil, :actual_version= => nil, :check_name= => nil)
        expect(results).to receive(:add_result).with(
          AuditResults::UNEXPECTED_VERSION, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version
        )
        allow(results).to receive(:add_result).with(any_args)
        allow(AuditResults).to receive(:new).and_return(results)
        c2m.check_catalog_version
      end

      it 'calls Stanford::StorageObjectValidator.validation_errors for moab' do
        mock_sov = instance_double(Stanford::StorageObjectValidator)
        expect(mock_sov).to receive(:validation_errors).and_return([])
        allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
        c2m.check_catalog_version
      end
      it 'valid moab sets status to UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
        orig = pres_copy.status
        c2m.check_catalog_version
        new_status = pres_copy.reload.status
        expect(new_status).not_to eq orig
        expect(new_status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
      end
      context 'invalid moab' do
        before do
          mock_sov = instance_double(Stanford::StorageObjectValidator)
          allow(mock_sov).to receive(:validation_errors).and_return([foo: 'error message'])
          allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
        end
        it 'sets status to INVALID_MOAB_STATUS' do
          orig = pres_copy.status
          c2m.check_catalog_version
          new_status = pres_copy.reload.status
          expect(new_status).not_to eq orig
          expect(new_status).to eq PreservedCopy::INVALID_MOAB_STATUS
        end
        it 'adds an INVALID_MOAB result' do
          results = instance_double(AuditResults, report_results: nil, :actual_version= => nil, :check_name= => nil)
          expect(results).to receive(:add_result).with(AuditResults::INVALID_MOAB, anything)
          allow(results).to receive(:add_result).with(any_args)
          allow(AuditResults).to receive(:new).and_return(results)
          c2m.check_catalog_version
        end
      end
      it 'adds a PC_STATUS_CHANGED result' do
        results = instance_double(AuditResults, report_results: nil, :actual_version= => nil, :check_name= => nil)
        expect(results).to receive(:add_result).with(
          AuditResults::PC_STATUS_CHANGED, a_hash_including(:old_status, :new_status)
        )
        allow(results).to receive(:add_result).with(any_args)
        allow(AuditResults).to receive(:new).and_return(results)
        c2m.check_catalog_version
      end

      context 'check whether PreservedCopy already has a status other than OK_STATUS, re-check status if so' do
        [
          PreservedCopy::VALIDITY_UNKNOWN_STATUS,
          PreservedCopy::OK_STATUS,
          PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
          PreservedCopy::INVALID_MOAB_STATUS,
          PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        ].each do |orig_status|
          it "had #{orig_status}, should now have EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS" do
            pres_copy.status = orig_status
            pres_copy.save!
            allow(c2m).to receive(:moab_validation_errors).and_return([])
            c2m.check_catalog_version
            expect(pres_copy.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
          end
        end

        [
          PreservedCopy::VALIDITY_UNKNOWN_STATUS,
          PreservedCopy::OK_STATUS,
          PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
          PreservedCopy::INVALID_MOAB_STATUS,
          PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        ].each do |orig_status|
          it "had #{orig_status}, should now have INVALID_MOAB_STATUS" do
            pres_copy.status = orig_status
            pres_copy.save!
            allow(c2m).to receive(:moab_validation_errors).and_return(
              [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
            )
            c2m.check_catalog_version
            expect(pres_copy.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
          end
        end
      end
    end
  end
end
