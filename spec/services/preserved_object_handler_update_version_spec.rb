require 'rails_helper'
require 'services/shared_examples_preserved_object_handler'

RSpec.describe PreservedObjectHandler do
  before do
    allow(WorkflowReporter).to receive(:report_error)
    allow(WorkflowReporter).to receive(:report_completed)
  end

  let(:db_update_failed_prefix) { "db update failed" }
  let(:default_prez_policy) { PreservationPolicy.default_policy }
  let(:druid) { 'ab123cd4567' }
  let(:incoming_size) { 9876 }
  let(:incoming_version) { 6 }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:cm) { po_handler.complete_moab }
  let(:po) { PreservedObject.find_by(druid: druid) }
  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, ms_root) }

  describe '#update_version' do
    it_behaves_like 'attributes validated', :update_version

    context 'in Catalog' do
      before do
        v2 = create(:preserved_object, druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        v2.complete_moabs.create!(
          version: v2.current_version,
          size: 1,
          moab_storage_root: ms_root,
          status: 'ok', # pretending we checked for moab validation errs at create time
          last_version_audit: Time.current,
          last_moab_validation: Time.current
        )
      end

      context 'incoming version newer than catalog versions (both) (happy path)' do
        context 'CompleteMoab' do
          context 'changed' do
            it "version becomes incoming_version" do
              expect { po_handler.update_version }.to change(cm, :version).to be(incoming_version)
            end
            it 'last_version_audit' do
              expect { po_handler.update_version }.to change(cm, :last_version_audit)
            end
            it 'size if supplied' do
              expect { po_handler.update_version }.to change(cm, :size)
            end
          end

          context 'unchanged' do
            it 'size if incoming size is nil' do
              po_handler = described_class.new(druid, incoming_version, nil, ms_root)
              expect { po_handler.update_version }.not_to change { po_handler.complete_moab.size }
            end
            it 'last_moab_validation' do
              expect { po_handler.update_version }.not_to change(cm, :last_moab_validation)
            end
          end

          context 'status' do
            context 'checksums_validated = false' do
              it 'starting status validity_unknown unchanged' do
                cm.update!(status: 'validity_unknown')
                expect { po_handler.update_version }.not_to change(cm, :status).from('validity_unknown')
              end
              context 'starting status not validity_unknown' do
                shared_examples 'POH#update_version changes status to "validity_unknown"' do |orig_status|
                  before { cm.update!(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect { po_handler.update_version }.to change(cm, :status)
                      .from(orig_status).to('validity_unknown')
                  end
                end

                it_behaves_like 'POH#update_version changes status to "validity_unknown"', 'ok'
                it_behaves_like 'POH#update_version changes status to "validity_unknown"', 'invalid_moab'
                it_behaves_like 'POH#update_version changes status to "validity_unknown"', 'invalid_checksum'
                it_behaves_like 'POH#update_version changes status to "validity_unknown"', 'online_moab_not_found'
                it_behaves_like 'POH#update_version changes status to "validity_unknown"', 'unexpected_version_on_storage'
              end
            end

            context 'checksums_validated = true' do
              it 'starting status ok unchanged' do
                expect { po_handler.update_version(true) }.not_to change(cm, :status).from('ok')
              end
              context 'original status was not ok' do
                shared_examples 'POH#update_version(true) does not change status' do |orig_status|
                  before { cm.update!(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect { po_handler.update_version(true) }.not_to change(cm, :status)
                  end
                end

                it_behaves_like 'POH#update_version(true) does not change status', 'validity_unknown'
                it_behaves_like 'POH#update_version(true) does not change status', 'invalid_moab'
                it_behaves_like 'POH#update_version(true) does not change status', 'invalid_checksum'
                # TODO: do these statuses change?
                it_behaves_like 'POH#update_version(true) does not change status', 'online_moab_not_found'
                it_behaves_like 'POH#update_version(true) does not change status', 'unexpected_version_on_storage'
              end
            end
          end
        end

        context 'calls #update_online_version with' do
          it 'status = "validity_unknown" for checksums_validated = false' do
            expect(po_handler).to receive(:update_online_version).with('validity_unknown', true, false).and_call_original
            po_handler.update_version
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end
          it 'status = "ok" and checksums_validated = true for checksums_validated = true' do
            expect(po_handler).to receive(:update_online_version).with(nil, true, true).and_call_original
            po_handler.update_version(true)
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end
        end

        context 'PreservedObject changed' do
          it "current_version becomes incoming version" do
            expect { po_handler.update_version }.to change(po_handler.pres_object, :current_version)
              .to(incoming_version)
          end
        end

        it_behaves_like 'calls AuditResults.report_results', :update_version

        context 'returns' do
          let!(:results) { po_handler.update_version(true) }

          it '1 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 1
          end
          it 'ACTUAL_VERS_GT_DB_OBJ results' do
            code = AuditResults::ACTUAL_VERS_GT_DB_OBJ
            version_gt_cm_msg = "actual version (#{incoming_version}) greater than CompleteMoab db version (2)"
            expect(results).to include(a_hash_including(code => version_gt_cm_msg))
          end
        end
      end

      context 'CompleteMoab and PreservedObject versions do not match' do
        before { cm.update(version: cm.version + 1) }

        it_behaves_like 'PreservedObject current_version does not match online CM version', :update_version, 3, 3, 2
      end

      context 'incoming version same as catalog versions (both)' do
        it_behaves_like 'unexpected version', :update_version, 2, 'ok'
      end

      context 'incoming version lower than catalog versions (both)' do
        it_behaves_like 'unexpected version', :update_version, 1
      end

      context 'db update error' do
        let(:result_code) { AuditResults::DB_UPDATE_FAILED }

        context 'CompleteMoab' do
          context 'ActiveRecordError' do
            let(:results) do
              allow(Rails.logger).to receive(:log)
              allow(po_handler).to receive(:pres_object).and_return(po)
              allow(po_handler).to receive(:comp_moab).and_return(cm)
              allow(cm).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
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
            let(:druid) { 'zy666xw4567' }
            let(:results) do
              allow(Rails.logger).to receive(:log)
              allow(po_handler).to receive(:pres_object).and_return(po)
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

      it 'calls PreservedObject.save! and CompleteMoab.save! if the records are altered' do
        allow(po_handler).to receive(:pres_object).and_return(po)
        allow(po_handler.pres_object.complete_moabs).to receive(:find_by!).with(moab_storage_root: ms_root).and_return(cm)
        expect(po).to receive(:save!)
        expect(cm).to receive(:save!)
        po_handler.update_version
      end

      it 'does not call PreservedObject.save when CompleteMoab only has timestamp updates' do
        po_handler = described_class.new(druid, 1, 1, ms_root)
        allow(po_handler).to receive(:pres_object).and_return(po)
        allow(po_handler.pres_object.complete_moabs).to receive(:find_by!).with(moab_storage_root: ms_root).and_return(cm)
        expect(cm).to receive(:save!)
        expect(po).not_to receive(:save!)
        po_handler.update_version
      end

      it 'logs a debug message' do
        allow(Rails.logger).to receive(:debug)
        po_handler.update_version
        expect(Rails.logger).to have_received(:debug).with("update_version #{druid} called")
      end
    end

    it_behaves_like 'druid not in catalog', :update_version

    it_behaves_like 'CompleteMoab does not exist', :update_version
  end

  describe '#update_version_after_validation' do
    let(:druid) { 'bp628nk4868' }
    let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root02/sdr2objects') }

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
          po.complete_moabs.create!(
            version: po.current_version,
            size: 1,
            moab_storage_root: ms_root,
            status: 'ok', # NOTE: pretending we checked for moab validation errs at create time
            last_version_audit: t,
            last_moab_validation: t
          )
        end

        let(:po) { PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy) }
        let(:cm) { po.complete_moabs.find_by!(moab_storage_root: ms_root) }

        context 'CompleteMoab' do
          context 'changed' do
            it 'last_version_audit' do
              orig = cm.last_version_audit
              po_handler.update_version_after_validation
              expect(cm.reload.last_version_audit).to be > orig
            end
            it 'last_moab_validation' do
              orig = cm.last_moab_validation
              po_handler.update_version_after_validation
              expect(cm.reload.last_moab_validation).to be > orig
            end
            it 'version becomes incoming_version' do
              orig = cm.version
              po_handler.update_version_after_validation
              expect(cm.reload.version).to be > orig
              expect(cm.version).to eq incoming_version
            end
            it 'size if supplied' do
              orig = cm.size
              po_handler.update_version_after_validation
              expect(cm.reload.size).to eq incoming_size
              expect(cm.size).not_to eq orig
            end
          end

          context 'unchanged' do
            it 'size if incoming size is nil' do
              orig = cm.size
              po_handler = described_class.new(druid, incoming_version, nil, ms_root)
              po_handler.update_version_after_validation
              expect(cm.reload.size).to eq orig
            end
          end

          context 'status' do
            context 'checksums_validated = false' do
              it 'starting status validity_unknown unchanged' do
                cm.update(status: 'validity_unknown')
                expect do
                  po_handler.update_version_after_validation
                end.not_to change { cm.reload.status }.from('validity_unknown')
              end
              context 'starting status not validity_unknown' do
                shared_examples 'POH#update_version_after_validation changes status to "validity_unknown"' do |orig_status|
                  before { cm.update(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect do
                      po_handler.update_version_after_validation
                    end.to change { cm.reload.status }.from(orig_status).to('validity_unknown')
                  end
                end

                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'ok'
                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'invalid_moab'
                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'invalid_checksum'
                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'online_moab_not_found'
                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'unexpected_version_on_storage'
              end
            end

            context 'checksums_validated = true' do
              it 'starting status ok unchanged' do
                expect do
                  po_handler.update_version_after_validation(true)
                end.not_to change { cm.reload.status }.from('ok')
              end
              context 'starting status not ok' do
                shared_examples 'POH#update_version_after_validation(true) changes status to "ok"' do |orig_status|
                  before { cm.update(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect do
                      po_handler.update_version_after_validation(true)
                    end.to change { cm.reload.status }.from(orig_status).to('ok')
                  end
                end

                it_behaves_like 'POH#update_version_after_validation(true) changes status to "ok"', 'validity_unknown'
                it_behaves_like 'POH#update_version_after_validation(true) changes status to "ok"', 'invalid_moab'
                it_behaves_like 'POH#update_version_after_validation(true) changes status to "ok"', 'invalid_checksum'
                it_behaves_like 'POH#update_version_after_validation(true) changes status to "ok"', 'online_moab_not_found'
                it_behaves_like 'POH#update_version_after_validation(true) changes status to "ok"', 'unexpected_version_on_storage'
              end
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

        context 'calls #update_online_version with' do
          it 'status = "validity_unknown" for checksums_validated = false' do
            expect(po_handler).to receive(:update_online_version).with('validity_unknown', false, false).and_call_original
            po_handler.update_version_after_validation(false)
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end
          it 'status = "ok" and checksums_validated = true for checksums_validated = true' do
            expect(po_handler).to receive(:update_online_version).with('ok', false, true).and_call_original
            po_handler.update_version_after_validation(true)
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end
        end
      end

      context 'when moab is invalid' do
        let(:druid) { 'xx000xx0000' }
        let(:storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
        let(:ms_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }

        before do
          MoabStorageRoot.find_or_create_by!(name: 'bad_fixture_dir') do |msr|
            msr.storage_location = storage_dir
          end
          po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
          t = Time.current
          CompleteMoab.create!(
            preserved_object: po,
            version: po.current_version,
            size: 1,
            moab_storage_root: ms_root,
            status: 'ok', # pretending we checked for moab validation errs at create time
            last_version_audit: t,
            last_moab_validation: t
          )
        end

        context 'checksums_validated = false' do
          context 'CompleteMoab' do
            it 'last_moab_validation updated' do
              expect do
                po_handler.update_version_after_validation
              end.to change { cm.reload.status }.from('ok').to('validity_unknown')
            end
            it 'size updated to incoming_size' do
              expect do
                po_handler.update_version_after_validation
              end.to change { cm.reload.size }.to(incoming_size)
            end
            it 'last_version_audit updated' do
              expect do
                po_handler.update_version_after_validation
              end.to change { cm.reload.last_version_audit }
            end
            it 'version updated to incoming_version' do
              expect do
                po_handler.update_version_after_validation
              end.to change { cm.reload.version }.from(2).to(incoming_version)
            end
            context 'status' do
              it 'starting status validity_unknown unchanged' do
                cm.update(status: 'validity_unknown')
                expect do
                  po_handler.update_version_after_validation
                end.not_to change { cm.reload.status }.from('validity_unknown')
              end
              context 'starting status was not validity_unknown' do
                shared_examples 'POH#update_version_after_validation changes status to "validity_unknown"' do |orig_status|
                  before { cm.update(status: orig_status) }

                  it "original status #{orig_status}" do
                    # (due to newer version not checksum validated)
                    expect do
                      po_handler.update_version_after_validation
                    end.to change { cm.reload.status }.from(orig_status).to('validity_unknown')
                  end
                end

                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'ok'
                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'online_moab_not_found'
                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'unexpected_version_on_storage'
                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'invalid_moab'
                it_behaves_like 'POH#update_version_after_validation changes status to "validity_unknown"', 'invalid_checksum'
              end
            end
          end
        end

        context 'checksums_validated = true' do
          context 'CompleteMoab' do
            it 'last_moab_validation updated' do
              expect do
                po_handler.update_version_after_validation(true)
              end.to change { cm.reload.last_moab_validation }
            end
            it 'size updated to incoming_size' do
              expect do
                po_handler.update_version_after_validation(true)
              end.to change { cm.reload.size }.to(incoming_size)
            end
            it 'last_version_audit updated' do
              expect do
                po_handler.update_version_after_validation(true)
              end.to change { cm.reload.last_version_audit }
            end
            it 'version updated to incoming_version' do
              expect do
                po_handler.update_version_after_validation(true)
              end.to change { cm.reload.version }.from(2).to(incoming_version)
            end
            context 'status' do
              it 'starting status invalid_moab unchanged' do
                cm.update(status: 'invalid_moab')
                expect do
                  po_handler.update_version_after_validation(true)
                end.not_to change { cm.reload.status }.from('invalid_moab')
              end
              context 'starting status was not invalid_moab' do
                shared_examples 'POH#update_version_after_validation(true) changes status to "invalid_moab"' do |orig_status|
                  before { cm.update(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect do
                      po_handler.update_version_after_validation(true)
                    end.to change { cm.reload.status }.from(orig_status).to('invalid_moab')
                  end
                end

                it_behaves_like 'POH#update_version_after_validation(true) changes status to "invalid_moab"', 'ok'
                it_behaves_like 'POH#update_version_after_validation(true) changes status to "invalid_moab"', 'validity_unknown'
                it_behaves_like 'POH#update_version_after_validation(true) changes status to "invalid_moab"', 'online_moab_not_found'
                it_behaves_like 'POH#update_version_after_validation(true) changes status to "invalid_moab"', 'unexpected_version_on_storage'
                it_behaves_like 'POH#update_version_after_validation(true) changes status to "invalid_moab"', 'invalid_checksum'
              end
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

        context 'calls #update_online_version with' do
          it 'status = "validity_unknown" for checksums_validated = false' do
            expect(po_handler).to receive(:update_online_version).with('validity_unknown', false, false).and_call_original
            po_handler.update_version_after_validation
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end
          it 'status = "invalid_moab" and checksums_validated = true for checksums_validated = true' do
            expect(po_handler).to receive(:update_online_version).with('invalid_moab', false, true).and_call_original
            po_handler.update_version_after_validation(true)
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end
        end

        it 'logs a debug message' do
          msg = "update_version_after_validation #{druid} called"
          allow(Rails.logger).to receive(:debug)
          po_handler.update_version_after_validation
          expect(Rails.logger).to have_received(:debug).with(msg)
        end

        context 'CompleteMoab and PreservedObject versions do not match' do
          before do
            cm.version = cm.version + 1
            cm.save!
          end

          context 'checksums_validated = false' do
            context 'CompleteMoab' do
              it 'last_moab_validation updated' do
                expect { po_handler.update_version_after_validation }.to change { cm.reload.last_moab_validation }
              end
              it 'last_version_audit unchanged' do
                expect { po_handler.update_version_after_validation }.not_to change { cm.reload.last_version_audit }
              end
              it 'size unchanged' do
                expect { po_handler.update_version_after_validation }.not_to change { cm.reload.size }
              end
              it 'version unchanged' do
                expect { po_handler.update_version_after_validation }.not_to change { cm.reload.version }
              end
              it 'status becomes validity_unknown (due to newer version not checksum validated)' do
                expect { po_handler.update_version_after_validation }.to change { cm.reload.status }.to('validity_unknown')
              end
            end

            it 'does not update PreservedObject' do
              expect { po_handler.update_version_after_validation }.not_to change { po.reload.updated_at }
            end

            context 'returns' do
              let!(:results) { po_handler.update_version_after_validation }

              it '3 results' do
                expect(results).to be_an_instance_of Array
                expect(results.size).to eq 3
              end
              it 'INVALID_MOAB result' do
                code = AuditResults::INVALID_MOAB
                invalid_moab_msg = "Invalid Moab, validation errors: [\"Missing directory: [\\\"data\\\", \\\"manifests\\\"] Version: v0001\"]"
                expect(results).to include(hash_including(code => invalid_moab_msg))
              end
              it 'CM_PO_VERSION_MISMATCH result' do
                code = AuditResults::CM_PO_VERSION_MISMATCH
                mismatch_msg = "CompleteMoab online Moab version 3 does not match PreservedObject current_version 2"
                expect(results).to include(hash_including(code => mismatch_msg))
              end
              it 'CM_STATUS_CHANGED result' do
                updated_status_msg_regex = Regexp.new("CompleteMoab status changed from")
                expect(results).to include(a_hash_including(AuditResults::CM_STATUS_CHANGED => updated_status_msg_regex))
              end
            end
          end

          context 'checksums_validated = true' do
            context 'CompleteMoab' do
              it 'last_moab_validation updated' do
                expect { po_handler.update_version_after_validation(true) }.to change { cm.reload.last_moab_validation }
              end
              it 'last_version_audit unchanged' do
                expect { po_handler.update_version_after_validation(true) }.not_to change { cm.reload.last_version_audit }
              end
              it 'size unchanged' do
                expect { po_handler.update_version_after_validation(true) }.not_to change { cm.reload.size }
              end
              it 'version unchanged' do
                expect { po_handler.update_version_after_validation(true) }.not_to change { cm.reload.version }
              end
              it 'status becomes invalid_moab' do
                expect { po_handler.update_version_after_validation(true) }.to change { cm.reload.status }.to('invalid_moab')
              end
            end

            it 'does not update PreservedObject' do
              expect { po_handler.update_version_after_validation(true) }.not_to change { po.reload.updated_at }
            end

            context 'returns' do
              let!(:results) { po_handler.update_version_after_validation(true) }

              it '3 results' do
                expect(results).to be_an_instance_of Array
                expect(results.size).to eq 3
              end
              it 'INVALID_MOAB result' do
                code = AuditResults::INVALID_MOAB
                invalid_moab_msg = "Invalid Moab, validation errors: [\"Missing directory: [\\\"data\\\", \\\"manifests\\\"] Version: v0001\"]"
                expect(results).to include(hash_including(code => invalid_moab_msg))
              end
              it 'CM_PO_VERSION_MISMATCH result' do
                code = AuditResults::CM_PO_VERSION_MISMATCH
                mismatch_msg = "CompleteMoab online Moab version 3 does not match PreservedObject current_version 2"
                expect(results).to include(hash_including(code => mismatch_msg))
              end
              it 'CM_STATUS_CHANGED result' do
                updated_status_msg_regex = Regexp.new("CompleteMoab status changed from")
                expect(results).to include(a_hash_including(AuditResults::CM_STATUS_CHANGED => updated_status_msg_regex))
              end
            end
          end
        end

        context 'incoming version same as catalog versions (both)' do
          it_behaves_like 'unexpected version with validation', :update_version_after_validation, 2, 'invalid_moab'
        end

        context 'incoming version lower than catalog versions (both)' do
          it_behaves_like 'unexpected version with validation', :update_version_after_validation, 1, 'invalid_moab'
        end

        context 'db update error' do
          let(:result_code) { AuditResults::DB_UPDATE_FAILED }

          context 'CompleteMoab' do
            context 'ActiveRecordError' do
              let(:results) do
                allow(Rails.logger).to receive(:log)
                allow(po_handler).to receive(:pres_object).and_return(po)
                allow(po_handler.pres_object.complete_moabs).to receive(:find_by!).with(moab_storage_root: ms_root).and_return(cm)
                allow(cm).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
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

    it_behaves_like 'CompleteMoab does not exist', :update_version_after_validation
  end
end
