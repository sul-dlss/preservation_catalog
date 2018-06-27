require 'rails_helper'
require 'services/shared_examples_preserved_object_handler'

RSpec.describe PreservedObjectHandler do
  before do
    allow(Dor::WorkflowService).to receive(:update_workflow_error_status)
  end

  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let!(:default_prez_policy) { PreservationPolicy.default_policy }
  let(:po) { PreservedObject.find_by(druid: druid) }
  let(:ep) { Endpoint.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:pc) { PreservedCopy.find_by(preserved_object: po, endpoint: ep) }
  let(:db_update_failed_prefix) { "db update failed" }

  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, ep) }

  describe '#update_version' do
    it_behaves_like 'attributes validated', :update_version

    context 'in Catalog' do
      before do
        po = create(:preserved_object, druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        create(
          :preserved_copy,
          preserved_object: po,
          version: po.current_version,
          size: 1,
          endpoint: ep,
          status: PreservedCopy::OK_STATUS, # pretending we checked for moab validation errs at create time
          last_version_audit: Time.current,
          last_moab_validation: Time.current
        )
      end

      context 'incoming version newer than catalog versions (both) (happy path)' do
        context 'PreservedCopy' do
          context 'changed' do
            it "version becomes incoming_version" do
              orig = pc.version
              po_handler.update_version
              expect(pc.reload.version).to be > orig
              expect(pc.version).to eq incoming_version
            end
            it 'last_version_audit' do
              orig = pc.last_version_audit
              po_handler.update_version
              expect(pc.reload.last_version_audit).to be > orig
            end
            it 'size if supplied' do
              orig = pc.size
              po_handler.update_version
              expect(pc.reload.size).to eq incoming_size
              expect(pc.size).not_to eq orig
            end
          end
          context 'unchanged' do
            it 'size if incoming size is nil' do
              orig = pc.size
              po_handler = described_class.new(druid, incoming_version, nil, ep)
              po_handler.update_version
              expect(pc.reload.size).to eq orig
            end
            it 'status' do
              expect { po_handler.update_version }.not_to change { pc.reload.status }.from('ok')
            end
            it 'last_moab_validation' do
              orig = pc.last_moab_validation
              po_handler.update_version
              expect(pc.reload.last_moab_validation).to eq orig
            end
          end
          context 'PreservedObject' do
            context 'changed' do
              it "current_version becomes incoming version" do
                orig = po.current_version
                po_handler.update_version
                expect(po.reload.current_version).to be > orig
                expect(po.current_version).to eq incoming_version
              end
            end
          end
        end
        it_behaves_like 'calls AuditResults.report_results', :update_version

        context 'returns' do
          let!(:results) { po_handler.update_version }

          it '1 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 1
          end
          it 'ACTUAL_VERS_GT_DB_OBJ results' do
            code = AuditResults::ACTUAL_VERS_GT_DB_OBJ
            version_gt_pc_msg = "actual version (#{incoming_version}) greater than PreservedCopy db version (2)"
            expect(results).to include(a_hash_including(code => version_gt_pc_msg))
          end
        end
      end

      context 'PreservedCopy and PreservedObject versions do not match' do
        before do
          pc.update(version: pc.version + 1)
        end

        it_behaves_like 'PreservedObject current_version does not match online PC version', :update_version, 3, 3, 2
      end

      context 'incoming version same as catalog versions (both)' do
        it_behaves_like 'unexpected version', :update_version, 2, PreservedCopy::OK_STATUS
      end

      context 'incoming version lower than catalog versions (both)' do
        it_behaves_like 'unexpected version', :update_version, 1
      end

      context 'db update error' do
        let(:result_code) { AuditResults::DB_UPDATE_FAILED }

        context 'PreservedCopy' do
          context 'ActiveRecordError' do
            let(:results) do
              allow(Rails.logger).to receive(:log)
              po = instance_double('PreservedObject', current_version: 1)
              allow(PreservedObject).to receive(:find_by!).with(druid: druid).and_return(po)
              pc = create :preserved_copy
              allow(PreservedCopy).to receive(:find_by!).with(preserved_object: po, endpoint: ep).and_return(pc)

              allow(pc).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              po_handler.update_version
            end

            context 'DB_UPDATE_FAILED error' do
              it 'prefix' do
                expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
              end
              it 'specific exception raised' do
                expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
              end
              it "exception's message" do
                expect(results).to include(a_hash_including(result_code => a_string_matching('foo')))
              end
            end
          end
        end
        context 'PreservedObject' do
          context 'ActiveRecordError' do
            let(:results) do
              allow(Rails.logger).to receive(:log)
              po = create :preserved_object, current_version: 5
              allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
              pc = create :preserved_copy
              allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)

              allow(po).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              po_handler.update_version
            end

            context 'DB_UPDATE_FAILED error' do
              it 'prefix' do
                expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
              end
              it 'specific exception raised' do
                expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
              end
              it "exception's message" do
                expect(results).to include(a_hash_including(result_code => a_string_matching('foo')))
              end
            end
          end
        end
      end

      it 'calls PreservedObject.save! and PreservedCopy.save! if the records are altered' do
        po = create :preserved_object
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        pc = create :preserved_copy
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)

        allow(po).to receive(:save!)
        allow(pc).to receive(:save!)
        po_handler.update_version
        expect(po).to have_received(:save!)
        expect(pc).to have_received(:save!)
      end

      it 'does not call PreservedObject.save when PreservedCopy only has timestamp updates' do
        po = create :preserved_object
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        pc = create :preserved_copy
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)

        allow(po).to receive(:save!)
        allow(pc).to receive(:save!)
        po_handler = described_class.new(druid, 1, 1, ep)
        po_handler.update_version
        expect(po).not_to have_received(:save!)
        expect(pc).to have_received(:save!)
      end

      it 'logs a debug message' do
        msg = "update_version #{druid} called"
        allow(Rails.logger).to receive(:debug)
        po_handler.update_version
        expect(Rails.logger).to have_received(:debug).with(msg)
      end
    end

    it_behaves_like 'druid not in catalog', :update_version

    it_behaves_like 'PreservedCopy does not exist', :update_version
  end

  describe '#update_version_after_validation' do
    let(:druid) { 'bp628nk4868' }
    let(:ep) { Endpoint.find_by(storage_location: 'spec/fixtures/storage_root02/sdr2objects') }

    it_behaves_like 'attributes validated', :update_version_after_validation

    it 'calls Stanford::StorageObjectValidator.validation_errors for moab' do
      mock_sov = instance_double(Stanford::StorageObjectValidator)
      expect(mock_sov).to receive(:validation_errors).and_return([])
      allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
      po_handler.update_version_after_validation
    end

    context 'in Catalog' do
      context 'when moab is valid' do
        before do
          t = Time.current
          PreservedCopy.create!(
            preserved_object: po,
            version: po.current_version,
            size: 1,
            endpoint: ep,
            status: PreservedCopy::OK_STATUS, # NOTE: pretending we checked for moab validation errs at create time
            last_version_audit: t,
            last_moab_validation: t
          )
        end
        let(:po) { PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy) }
        let(:pc) { PreservedCopy.find_by!(preserved_object: po, endpoint: ep) }

        context 'PreservedCopy' do
          context 'changed' do
            it 'last_version_audit' do
              orig = pc.last_version_audit
              po_handler.update_version_after_validation
              expect(pc.reload.last_version_audit).to be > orig
            end
            it 'last_moab_validation' do
              orig = pc.last_moab_validation
              po_handler.update_version_after_validation
              expect(pc.reload.last_moab_validation).to be > orig
            end
            it 'version becomes incoming_version' do
              orig = pc.version
              po_handler.update_version_after_validation
              expect(pc.reload.version).to be > orig
              expect(pc.version).to eq incoming_version
            end
            it 'size if supplied' do
              orig = pc.size
              po_handler.update_version_after_validation
              expect(pc.reload.size).to eq incoming_size
              expect(pc.size).not_to eq orig
            end
          end
          context 'unchanged' do
            it 'size if incoming size is nil' do
              orig = pc.size
              po_handler = described_class.new(druid, incoming_version, nil, ep)
              po_handler.update_version_after_validation
              expect(pc.reload.size).to eq orig
            end
            it 'status' do
              po_handler.update_version_after_validation
              expect(pc.reload).to be_validity_unknown
              skip 'is there a scenario when status should change here?  See #431'
            end
          end
        end
        context 'PreservedObject' do
          context 'changed' do
            it 'current_version' do
              orig = po.current_version
              po_handler.update_version_after_validation
              expect(po.reload.current_version).to eq po_handler.incoming_version
              expect(po.current_version).to be > orig
            end
          end
        end

        it 'calls #update_online_version with validated = true and status = "validity_unknown"' do
          expect(po_handler).to receive(:update_online_version).with(PreservedCopy::VALIDITY_UNKNOWN_STATUS).and_call_original
          po_handler.update_version_after_validation
          skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
        end

        it 'updates PreservedCopy status to "validity_unknown" if it was "moab_invalid"' do
          pc.status = PreservedCopy::INVALID_MOAB_STATUS
          pc.save!
          po_handler.update_version_after_validation
          expect(pc.reload.status).to eq PreservedCopy::VALIDITY_UNKNOWN_STATUS
        end
      end

      context 'when moab is invalid' do
        let(:druid) { 'xx000xx0000' }
        let(:storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
        let(:ep) { Endpoint.find_by(storage_location: storage_dir) }

        before do
          Endpoint.find_or_create_by!(endpoint_name: 'bad_fixture_dir') do |endpoint|
            endpoint.endpoint_type = EndpointType.default_for_storage_roots
            endpoint.endpoint_node = Settings.endpoints.storage_root_defaults.endpoint_node
            endpoint.storage_location = storage_dir
          end
          po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
          t = Time.current
          PreservedCopy.create!(
            preserved_object: po,
            version: po.current_version,
            size: 1,
            endpoint: ep,
            status: PreservedCopy::OK_STATUS, # pretending we checked for moab validation errs at create time
            last_version_audit: t,
            last_moab_validation: t
          )
        end

        context 'PreservedCopy' do
          context 'changed' do
            it 'last_moab_validation' do
              orig = pc.last_moab_validation
              po_handler.update_version_after_validation
              expect(pc.reload.last_moab_validation).to be > orig
            end
            it 'status' do
              orig = pc.status
              po_handler.update_version_after_validation
              expect(pc.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
              expect(pc.status).not_to eq orig
            end
          end
          context 'unchanged' do
            it 'version' do
              orig = pc.version
              po_handler.update_version_after_validation
              expect(pc.reload.version).to eq orig
            end
            it 'size' do
              orig = pc.size
              po_handler.update_version_after_validation
              expect(pc.reload.size).to eq orig
            end
            it 'last_version_audit' do
              orig = pc.last_version_audit
              po_handler.update_version_after_validation
              expect(pc.reload.last_version_audit).to eq orig
            end
          end
        end
        context 'PreservedObject' do
          context 'unchanged' do
            it 'current_version' do
              orig = po.current_version
              po_handler.update_version_after_validation
              expect(po.current_version).to eq orig
            end
          end
        end

        it 'ensures PreservedCopy status is invalid' do
          pc.status = PreservedCopy::OK_STATUS
          pc.save!
          po_handler.update_version_after_validation
          expect(pc.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
        end

        it 'logs a debug message' do
          msg = "update_version_after_validation #{druid} called"
          allow(Rails.logger).to receive(:debug)
          po_handler.update_version_after_validation
          expect(Rails.logger).to have_received(:debug).with(msg)
        end

        it 'does not call PreservedObject.save! when PreservedCopy only has timestamp updates' do
          po = create :preserved_object
          allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
          pc = create :preserved_copy
          allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
          allow(po_handler).to receive(:moab_validation_errors).and_return(['foo'])

          allow(po).to receive(:save!)
          allow(pc).to receive(:save!)
          po_handler.update_version_after_validation
          expect(po).not_to have_received(:save!)
          expect(pc).to have_received(:save!)
        end

        context 'incoming version newer than catalog versions (both) (happy path)' do
          it 'calls #update_online_version with validated = true and status = "invalid_moab"' do
            expect(po_handler).to receive(:update_online_version).with(true, PreservedCopy::INVALID_MOAB_STATUS).and_call_original
            po_handler.update_version_after_validation
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end
        end

        context 'PreservedCopy and PreservedObject versions do not match' do
          before do
            pc.version = pc.version + 1
            pc.save!
          end

          it_behaves_like 'update for invalid moab', :update_version_after_validation
        end

        context 'incoming version same as catalog versions (both)' do
          it_behaves_like 'unexpected version with validation', :update_version_after_validation, 2, PreservedCopy::INVALID_MOAB_STATUS
        end

        context 'incoming version lower than catalog versions (both)' do
          it_behaves_like 'unexpected version with validation', :update_version_after_validation, 1, PreservedCopy::INVALID_MOAB_STATUS
        end

        context 'db update error' do
          let(:result_code) { AuditResults::DB_UPDATE_FAILED }

          context 'PreservedCopy' do
            context 'ActiveRecordError' do
              let(:results) do
                allow(Rails.logger).to receive(:log)
                po = instance_double(PreservedObject, current_version: 1)
                allow(PreservedObject).to receive(:find_by!).with(druid: druid).and_return(po)
                pc = create :preserved_copy
                allow(PreservedCopy).to receive(:find_by!).with(preserved_object: po, endpoint: ep).and_return(pc)

                allow(pc).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
                po_handler.update_version_after_validation
              end

              context 'DB_UPDATE_FAILED error' do
                it 'prefix' do
                  expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
                end
                it 'specific exception raised' do
                  expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
                end
                it "exception's message" do
                  expect(results).to include(a_hash_including(result_code => a_string_matching('foo')))
                end
              end
            end
          end
          # PreservedObject won't get updated if moab is invalid
        end
      end
    end

    it_behaves_like 'druid not in catalog', :update_version_after_validation

    it_behaves_like 'PreservedCopy does not exist', :update_version_after_validation
  end
end
