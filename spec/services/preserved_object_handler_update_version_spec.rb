require 'rails_helper'
require 'services/shared_examples_preserved_object_handler'

RSpec.describe PreservedObjectHandler do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let!(:default_prez_policy) { PreservationPolicy.default_policy }
  let(:po) { PreservedObject.find_by(druid: druid) }
  let(:ep) { Endpoint.find_by(storage_location: 'spec/fixtures/storage_root01/moab_storage_trunk') }
  let(:pc) { PreservedCopy.find_by(preserved_object: po, endpoint: ep) }
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{ep.endpoint_name})" }
  let(:updated_status_msg_regex) { Regexp.new(Regexp.escape("#{exp_msg_prefix} PreservedCopy status changed from")) }
  let(:db_update_failed_prefix_regex_escaped) { Regexp.escape("#{exp_msg_prefix} db update failed") }
  let(:version_gt_pc_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedCopy db version" }
  let(:version_gt_po_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedObject db version" }
  let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }
  let(:updated_po_db_msg) { "#{exp_msg_prefix} PreservedObject db object updated" }
  let(:updated_po_db_timestamp_msg) { "#{exp_msg_prefix} PreservedObject updated db timestamp only" }
  let(:updated_pc_db_timestamp_msg) { "#{exp_msg_prefix} PreservedCopy updated db timestamp only" }

  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, ep) }

  describe '#update_version' do
    it_behaves_like 'attributes validated', :update_version

    context 'in Catalog' do
      before do
        po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        @pc = PreservedCopy.create!(
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
              orig = pc.status
              po_handler.update_version
              expect(pc.reload.status).to eq orig
              skip 'is there a scenario when status should change here?  See #431'
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
        it "logs at info level" do
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_po_db_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
          expect(Rails.logger).not_to receive(:log).with(Logger::INFO, updated_status_msg_regex)
          po_handler.update_version
        end

        context 'returns' do
          let!(:results) { po_handler.update_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '4 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 4
          end
          it 'ARG_VERSION_GREATER_THAN_DB_OBJECT results' do
            code = PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT
            expect(results).to include(a_hash_including(code => version_gt_pc_msg))
            expect(results).to include(a_hash_including(code => version_gt_po_msg))
          end
          it "UPDATED_DB_OBJECT results" do
            code = PreservedObjectHandlerResults::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_msg))
            expect(results).to include(a_hash_including(code => updated_po_db_msg))
          end
        end
      end

      context 'PreservedCopy and PreservedObject versions do not match' do
        before do
          @pc.version = @pc.version + 1
          @pc.save!
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
        let(:result_code) { PreservedObjectHandlerResults::DB_UPDATE_FAILED }

        context 'PreservedCopy' do
          context 'ActiveRecordError' do
            let(:results) do
              allow(Rails.logger).to receive(:log)
              # FIXME: couldn't figure out how to put next line into its own test
              expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{db_update_failed_prefix_regex_escaped}/)

              po = instance_double('PreservedObject')
              allow(po).to receive(:current_version).and_return(1)
              allow(PreservedObject).to receive(:find_by!).with(druid: druid).and_return(po)
              pc = instance_double('PreservedCopy')
              allow(PreservedCopy).to receive(:find_by!).with(preserved_object: po, endpoint: ep).and_return(pc)
              allow(pc).to receive(:version).and_return(1)
              allow(pc).to receive(:version=)
              allow(pc).to receive(:size=)
              allow(pc).to receive(:status).and_return(PreservedCopy::OK_STATUS)
              allow(pc).to receive(:status=)
              allow(pc).to receive(:last_version_audit=)
              allow(pc).to receive(:changed?).and_return(true)
              allow(pc).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              po_handler.update_version
            end

            context 'DB_UPDATE_FAILED error' do
              it 'prefix' do
                expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix_regex_escaped)))
              end
              it 'specific exception raised' do
                expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
              end
              it "exception's message" do
                expect(results).to include(a_hash_including(result_code => a_string_matching('foo')))
              end
              it 'does NOT get UPDATED_DB_OBJECT message' do
                expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT))
                expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
              end
            end
          end
        end
        context 'PreservedObject' do
          context 'ActiveRecordError' do
            let(:results) do
              allow(Rails.logger).to receive(:log)
              # FIXME: couldn't figure out how to put next line into its own test
              expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{db_update_failed_prefix_regex_escaped}/)

              po = instance_double('PreservedObject')
              allow(po).to receive(:current_version).and_return(5)
              allow(po).to receive(:current_version=).with(incoming_version)
              allow(po).to receive(:changed?).and_return(true)
              allow(po).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
              pc = instance_double('PreservedCopy')
              allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
              allow(pc).to receive(:version).and_return(5)
              allow(pc).to receive(:version=).with(incoming_version)
              allow(pc).to receive(:size=).with(incoming_size)
              allow(pc).to receive(:status).and_return(PreservedCopy::OK_STATUS)
              allow(pc).to receive(:status=)
              allow(pc).to receive(:last_version_audit=)
              allow(pc).to receive(:changed?).and_return(true)
              allow(pc).to receive(:save!)
              po_handler.update_version
            end

            context 'DB_UPDATE_FAILED error' do
              it 'prefix' do
                expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix_regex_escaped)))
              end
              it 'specific exception raised' do
                expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
              end
              it "exception's message" do
                expect(results).to include(a_hash_including(result_code => a_string_matching('foo')))
              end
              it 'does NOT get UPDATED_DB_OBJECT message' do
                expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT))
                expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
              end
            end
          end
        end
      end

      it 'calls PreservedObject.save! and PreservedCopy.save! if the records are altered' do
        po = instance_double(PreservedObject)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:current_version=).with(incoming_version)
        allow(po).to receive(:changed?).and_return(true)
        allow(po).to receive(:save!)
        pc = instance_double(PreservedCopy)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:version=).with(incoming_version)
        allow(pc).to receive(:size=).with(incoming_size)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:status).and_return(PreservedCopy::OK_STATUS)
        allow(pc).to receive(:status=)
        allow(pc).to receive(:last_version_audit=)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:save!)
        po_handler.update_version
        expect(po).to have_received(:save!)
        expect(pc).to have_received(:save!)
      end

      it 'does not call PreservedObject.touch when PreservedCopy only has timestamp updates' do
        po = instance_double(PreservedObject)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:touch)
        pc = instance_double(PreservedCopy)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:last_version_audit=)
        allow(pc).to receive(:status)
        allow(pc).to receive(:status=)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:save!)
        po_handler = described_class.new(druid, 1, 1, ep)
        po_handler.update_version
        expect(po).not_to have_received(:touch)
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
    let(:ep) { Endpoint.find_by(storage_location: 'spec/fixtures/storage_root02/moab_storage_trunk') }

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
              orig = pc.status
              po_handler.update_version_after_validation
              expect(pc.reload.status).to eq orig
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

        it 'calls #update_online_version with validated = true and status = "ok"' do
          expect(po_handler).to receive(:update_online_version).with(true, PreservedCopy::OK_STATUS).and_call_original
          po_handler.update_version_after_validation
          skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
        end

        it 'updates PreservedCopy status to "ok" if it was "moab_invalid"' do
          pc.status = PreservedCopy::INVALID_MOAB_STATUS
          pc.save!
          po_handler.update_version_after_validation
          expect(pc.reload.status).to eq PreservedCopy::OK_STATUS
        end
      end

      context 'when moab is invalid' do
        let(:druid) { 'xx000xx0000' }
        let(:storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
        let(:ep) { Endpoint.find_by(storage_location: storage_dir) }

        before do
          Endpoint.find_or_create_by!(endpoint_name: 'bad_fixture_dir') do |endpoint|
            endpoint.endpoint_type = Endpoint.default_storage_root_endpoint_type
            endpoint.endpoint_node = Settings.endpoints.storage_root_defaults.endpoint_node
            endpoint.storage_location = storage_dir
            endpoint.recovery_cost = Settings.endpoints.storage_root_defaults.recovery_cost
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

        it 'does not call PreservedObject.touch when PreservedCopy only has timestamp updates' do
          po = instance_double(PreservedObject)
          allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
          allow(po).to receive(:touch)
          pc = instance_double(PreservedCopy)
          allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
          allow(pc).to receive(:version).and_return(1)
          allow(pc).to receive(:version=).with(incoming_version)
          allow(pc).to receive(:size=).with(incoming_size)
          allow(pc).to receive(:endpoint).with(ep)
          allow(pc).to receive(:status).and_return(PreservedCopy::OK_STATUS)
          allow(pc).to receive(:status=)
          allow(pc).to receive(:last_version_audit=)
          allow(pc).to receive(:last_moab_validation=)
          allow(pc).to receive(:changed?).and_return(true)
          allow(pc).to receive(:save!)
          allow(po_handler).to receive(:moab_validation_errors).and_return(['foo'])
          po_handler.update_version_after_validation
          expect(po).not_to have_received(:touch)
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
          let(:result_code) { PreservedObjectHandlerResults::DB_UPDATE_FAILED }

          context 'PreservedCopy' do
            context 'ActiveRecordError' do
              let(:results) do
                allow(Rails.logger).to receive(:log)
                # FIXME: couldn't figure out how to put next line into its own test
                expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{db_update_failed_prefix_regex_escaped}/)

                po = instance_double('PreservedObject')
                allow(po).to receive(:current_version).and_return(1)
                allow(PreservedObject).to receive(:find_by!).with(druid: druid).and_return(po)
                pc = instance_double('PreservedCopy')
                allow(PreservedCopy).to receive(:find_by!).with(preserved_object: po, endpoint: ep).and_return(pc)
                allow(pc).to receive(:version).and_return(1)
                allow(pc).to receive(:version=)
                allow(pc).to receive(:status).and_return(PreservedCopy::OK_STATUS)
                allow(pc).to receive(:status=)
                allow(pc).to receive(:last_version_audit=)
                allow(pc).to receive(:last_moab_validation=)
                allow(pc).to receive(:changed?).and_return(true)
                allow(pc).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
                allow(pc).to receive(:size=)
                po_handler.update_version_after_validation
              end

              context 'DB_UPDATE_FAILED error' do
                it 'prefix' do
                  expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix_regex_escaped)))
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
      end
    end

    it_behaves_like 'druid not in catalog', :update_version_after_validation

    it_behaves_like 'PreservedCopy does not exist', :update_version_after_validation
  end
end
