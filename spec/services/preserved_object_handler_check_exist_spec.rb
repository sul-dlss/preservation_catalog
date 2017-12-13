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
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{ep})" }
  let(:db_update_failed_prefix_regex_escaped) { Regexp.escape("#{exp_msg_prefix} db update failed") }
  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, ep) }

  describe '#check_existence' do
    it_behaves_like 'attributes validated', :check_existence

    context 'druid in db' do
      before do
        po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        PreservedCopy.create!(
          preserved_object: po, # TODO: see if we got the preserved object that we expected
          version: po.current_version,
          size: 1,
          endpoint: ep,
          status: PreservedCopy::DEFAULT_STATUS
        )
      end

      context "incoming and db versions match" do
        let(:po_handler) { described_class.new(druid, 2, 1, ep) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 2, 1, #{ep})" }
        let(:version_matches_po_msg) { "#{exp_msg_prefix} incoming version (2) matches PreservedObject db version" }
        let(:version_matches_pc_msg) { "#{exp_msg_prefix} incoming version (2) matches PreservedCopy db version" }
        let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }

        context 'PreservedCopy' do
          context 'changed' do
            it 'last_audited' do
              orig = pc.last_audited
              po_handler.check_existence
              expect(pc.reload.last_audited).not_to eq orig
            end
            it 'last_checked_on_storage' do
              orig = pc.last_checked_on_storage
              po_handler.check_existence
              expect(pc.reload.last_checked_on_storage).not_to eq orig
            end
            it 'updated_at' do
              orig = pc.updated_at
              po_handler.check_existence
              expect(pc.reload.updated_at).to be > orig
            end
          end
          context 'unchanged' do
            it 'status' do
              orig = pc.status
              po_handler.check_existence
              expect(pc.reload.status).to eq orig
            end
            it 'version' do
              orig = pc.version
              po_handler.check_existence
              expect(pc.reload.version).to eq orig
            end
            it 'size' do
              orig = pc.size
              po_handler.check_existence
              expect(pc.reload.size).to eq orig
            end
          end
        end
        it 'PreservedObject is not updated' do
          orig_timestamp = po.updated_at
          po_handler.check_existence
          expect(po.reload.updated_at).to eq orig_timestamp
        end
        it "logs at info level" do
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
          po_handler.check_existence
        end
        it 'does not validate moab' do
          expect(po_handler).not_to receive(:moab_validation_errors)
          po_handler.check_existence
        end
        context 'returns' do
          let!(:results) { po_handler.check_existence }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '3 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 3
          end
          it 'VERSION_MATCHES results' do
            code = PreservedObjectHandlerResults::VERSION_MATCHES
            expect(results).to include(a_hash_including(code => version_matches_pc_msg))
            expect(results).to include(a_hash_including(code => version_matches_po_msg))
          end
          it 'UPDATED_DB_OBJECT PreservedCopy result' do
            code = PreservedObjectHandlerResults::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_msg))
          end
        end
      end

      context "incoming version > db version" do
        let(:incoming_version) { 6 }
        let(:incoming_size) { 9876 }
        let(:version_gt_pc_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedCopy db version" }
        let(:version_gt_po_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedObject db version" }
        let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }
        let(:updated_po_db_msg) { "#{exp_msg_prefix} PreservedObject db object updated" }
        let(:updated_status_msg_regex) { Regexp.new(Regexp.escape("#{exp_msg_prefix} PreservedCopy status changed from")) }


        it 'calls Stanford::StorageObjectValidator.validation_errors for moab' do
          # FIXME: prefer the first code below but since even the second version doesn't pass, leaving it for now
          # mock_sov = instance_double(Stanford::StorageObjectValidator)
          # expect(mock_sov).to receive(:validation_errors).and_return([])
          # allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
          # po_handler.check_existence

          expect(po_handler).to receive(:moab_validation_errors)
          po_handler.check_existence
        end

        context 'when moab is valid' do
          context 'PreservedCopy' do
            context 'changed' do
              it 'version to incoming_version' do
                orig = pc.version
                po_handler.check_existence
                expect(pc.reload.version).to be > orig
                expect(pc.reload.version).to eq incoming_version
              end
              it 'size if supplied' do
                orig = pc.size
                po_handler.check_existence
                expect(pc.reload.size).not_to eq orig
                expect(pc.reload.size).to eq incoming_size
              end
              it 'last_audited' do
                orig = Time.current.to_i
                pc.last_audited = orig
                pc.save!
                sleep 1 # last_audited is bigint, and granularity is second, not fraction thereof
                po_handler.check_existence
                expect(pc.reload.last_audited).to be > orig
              end
              it 'last_checked_on_storage' do
                orig = Time.current
                pc.last_checked_on_storage = orig
                pc.save!
                po_handler.check_existence
                expect(pc.reload.last_checked_on_storage).to be > orig
              end
              it 'updated_at' do
                orig = pc.updated_at
                po_handler.check_existence
                expect(pc.reload.updated_at).to be > orig
              end
              it 'status becomes "ok" if it was invalid_moab (b/c after validation)' do
                pc.status = PreservedCopy::INVALID_MOAB_STATUS
                pc.save!
                po_handler.check_existence
                expect(pc.reload.status).to eq PreservedCopy::OK_STATUS
              end
            end
            context 'unchanged' do
              it 'status if former status was ok' do
                pc.status = PreservedCopy::OK_STATUS
                pc.save!
                po_handler.check_existence
                expect(pc.reload.status).to eq PreservedCopy::OK_STATUS
              end
              it 'size if incoming size is nil' do
                orig = pc.size
                po_handler = described_class.new(druid, incoming_version, nil, ep)
                po_handler.check_existence
                expect(pc.reload.size).to eq orig
              end
            end
            it 'what about other statuses????' do
              fail 'need to know what to do when status does NOT start as ok or invalid moab'
              pc.status = PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS
              pc.save!
              po_handler.check_existence
              expect(pc.reload.status).to eq PreservedCopy::OK_STATUS
              # TODO: not clear what to do here;  it's not OK_STATUS if we didn't validate ...
              expect(pc.status).to eq PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS
            end
          end
          context 'PreservedObject' do
            context 'changed' do
              it 'current_version' do
                orig = po.current_version
                po_handler.check_existence
                expect(po.reload.current_version).to be > orig
                expect(po.reload.current_version).to eq incoming_version
              end
              it 'updated_at' do
                orig = pc.updated_at
                po_handler.check_existence
                expect(pc.reload.updated_at).to be > orig
              end
            end
          end

          it "logs at info level" do
            expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_po_msg)
            expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_pc_msg)
            expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_po_db_msg)
            expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
            expect(Rails.logger).not_to receive(:log).with(Logger::INFO, updated_status_msg_regex)
            po_handler.check_existence
          end

          context 'returns' do
            let!(:results) { po_handler.check_existence }

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
            it 'what results/logging desired for incoming version > catalog' do
              fail 'we need clarification of requirements on results/logging in this case'
            end
          end
        end

        context 'when moab is invalid' do
          let(:invalid_druid) { 'xx000xx0000' }
          let(:invalid_storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
          let(:invalid_ep) { Endpoint.find_by(storage_location: invalid_storage_dir) }

          before do
            # add storage root with the invalid moab to the Endpoints table
            Endpoint.find_or_create_by!(endpoint_name: 'bad_fixture_dir') do |endpoint|
              endpoint.endpoint_type = Endpoint.default_storage_root_endpoint_type
              endpoint.endpoint_node = Settings.endpoints.storage_root_defaults.endpoint_node
              endpoint.storage_location = invalid_storage_dir
              endpoint.recovery_cost = Settings.endpoints.storage_root_defaults.recovery_cost
            end
            # these need to be in before loop so it happens before each context below
            PreservedObject.create!(druid: invalid_druid, current_version: 2, preservation_policy: default_prez_policy)
            PreservedCopy.create!(
              preserved_object: po, # TODO: see if we got the preserved object that we expected
              version: po.current_version,
              size: 1,
              endpoint: invalid_ep,
              status: PreservedCopy::OK_STATUS,
              last_audited: Time.current.to_i,
              last_checked_on_storage: Time.current
            )
          end

          context 'PreservedCopy' do
            context 'changed' do
              it 'last_audited' do
                orig = pc.last_audited
                sleep 1 # last_audited is bigint, and granularity is second, not fraction thereof
                po_handler.check_existence
                expect(pc.reload.last_audited).to be > orig
              end
              it 'last_checked_on_storage' do
                orig = pc.last_checked_on_storage
                po_handler.check_existence
                expect(pc.reload.last_checked_on_storage).to be > orig
              end
              it 'updated_at' do
                orig = pc.updated_at
                po_handler.check_existence
                expect(pc.reload.updated_at).to be > orig
              end
              it 'ensures status becomes invalid_moab' do
                pc.status = PreservedCopy::OK_STATUS
                pc.save!
                po_handler.check_existence
                expect(pc.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
                pc.status = PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS
                pc.save!
                po_handler.check_existence
                expect(pc.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
              end
            end
            context 'unchanged' do
              it 'version' do
                orig = pc.version
                po_handler.check_existence
                expect(pc.reload.version).to eq orig
              end
              it 'size' do
                orig = pc.size
                po_handler.check_existence
                expect(pc.reload.size).to eq orig
              end
            end
          end
          it 'PreservedObject is not updated' do
            orig_timestamp = po.updated_at
            po_handler.confirm_version
            expect(po.reload.updated_at).to eq orig_timestamp
          end

          it 'logs at error level' do
            invalid_druid = 'yy000yy0000'
            po_handler = described_class.new(invalid_druid, incoming_version, incoming_size, ep)
            exp_msg_prefix = "PreservedObjectHandler(#{invalid_druid}, #{incoming_version}, #{incoming_size}, #{ep})"
            allow(Rails.logger).to receive(:log)
            errors = "#{exp_msg_prefix} Invalid moab, validation errors: [\"Missing directory: [\\\"manifests\\\"] Version: v0001\"]"
            expect(Rails.logger).to receive(:log).with(Logger::ERROR, errors)
            po_handler.check_existence
            fail 'want to refactor and shorten this test'
          end

          context 'returns' do
            let!(:results) { po_handler.check_existence }

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
              expect(results).to include(hash_not_including(code => updated_po_db_msg))
            end
            it 'INVALID_MOAB result' do
              expect(results).to include(a_hash_including(PreservedObjectHandlerResults::INVALID_MOAB))
            end
            it 'what results/logging desired for incoming version > catalog and invalid moab' do
              fail 'we need clarification of requirements on results/logging in this case'
            end
          end
        end
      end

      context 'incoming version < db version' do
        it_behaves_like 'unexpected version', 1
      end

      # context 'incoming version does NOT match db version' do
      #   let(:po_handler) { described_class.new(druid, 1, 666, ep) }
      #   let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 1, 666, #{ep})" }
      #   let(:unexpected_version_pc_msg) {
      #     "#{exp_msg_prefix} incoming version (1) has unexpected relationship to PreservedCopy db version; ERROR!"
      #   }
      #   let(:updated_pc_db_status_msg) {
      #     "#{exp_msg_prefix} PreservedCopy status changed from ok to expected_vers_not_found_on_storage"
      #   }
      #   let(:updated_pc_db_obj_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }
      #
      #   context 'PreservedCopy' do
      #     context 'changed' do
      #       it 'status to expected_vers_not_found_on_storage' do
      #         expect(pc.status).to eq PreservedCopy::OK_STATUS
      #         po_handler.check_existence
      #         expect(pc.reload.status).to eq PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS
      #       end
      #       it 'last_audited' do
      #         orig = Time.current.to_i
      #         pc.last_audited = orig
      #         pc.save!
      #         sleep 1 # last_audited is bigint, and granularity is second, not fraction thereof
      #         po_handler.check_existence
      #         expect(pc.reload.last_audited).to be > orig
      #       end
      #       it 'last_checked_on_storage' do
      #         orig = Time.current
      #         pc.last_checked_on_storage = orig
      #         pc.save!
      #         po_handler.check_existence
      #         expect(pc.reload.last_checked_on_storage).to be > orig
      #       end
      #       it 'updated_at' do
      #         orig = pc.updated_at
      #         po_handler.check_existence
      #         expect(pc.reload.updated_at).to be > orig
      #       end
      #     end
      #     context 'unchanged' do
      #       it 'version' do
      #         orig = pc.version
      #         po_handler.check_existence
      #         expect(pc.reload.version).to eq orig
      #       end
      #       it 'size' do
      #         orig = pc.size
      #         po_handler.check_existence
      #         expect(pc.reload.size).to eq orig
      #       end
      #     end
      #   end
      #   it 'PreservedObject is not updated' do
      #     orig_timestamp = po.updated_at
      #     po_handler.check_existence
      #     expect(po.reload.updated_at).to eq orig_timestamp
      #   end
      #
      #   it "logs at error level" do
      #     expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_status_msg)
      #     expect(Rails.logger).to receive(:log).with(Logger::ERROR, unexpected_version_pc_msg)
      #     expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_obj_msg)
      #     po_handler.check_existence
      #   end
      #   context 'returns' do
      #     let!(:results) { po_handler.check_existence }
      #
      #     # results = [result1, result2]
      #     # result1 = {response_code: msg}
      #     # result2 = {response_code: msg}
      #     it '3 results' do
      #       expect(results).to be_an_instance_of Array
      #       expect(results.size).to eq 3
      #     end
      #     it 'UNEXPECTED_VERSION PreservedCopy result' do
      #       code = PreservedObjectHandlerResults::UNEXPECTED_VERSION
      #       expect(results).to include(a_hash_including(code => unexpected_version_pc_msg))
      #     end
      #     it 'UPDATED_DB_OBJECT PreservedCopy result' do
      #       code = PreservedObjectHandlerResults::UPDATED_DB_OBJECT
      #       expect(results).to include(a_hash_including(code => updated_pc_db_obj_msg))
      #     end
      #     it "PC_STATUS_CHANGED PreservedCopy result" do
      #       code = PreservedObjectHandlerResults::PC_STATUS_CHANGED
      #       expect(results).to include(a_hash_including(code => updated_pc_db_status_msg))
      #     end
      #   end
      # end

      context 'PreservedCopy version does NOT match PreservedObject current_version (online Moab)' do
        before do
          po.current_version = 8
          po.save!
        end
        let(:version_mismatch_msg) { "#{exp_msg_prefix} PreservedCopy online moab version does not match PreservedObject current_version" }

        it "logs at error level" do
          expect(Rails.logger).to receive(:log).with(Logger::ERROR, version_mismatch_msg)
          po_handler.check_existence
        end
        it 'does not update PreservedCopy' do
          orig_timestamp = pc.updated_at
          po_handler.check_existence
          expect(pc.reload.updated_at).to eq orig_timestamp
        end
        it 'does not update PreservedObject' do
          orig_timestamp = po.reload.updated_at
          po_handler.check_existence
          expect(po.reload.updated_at).to eq orig_timestamp
        end
        context 'returns' do
          let!(:results) { po_handler.check_existence }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '1 result' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 1
          end
          it 'PC_PO_VERSION_MISMATCH result' do
            code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
            expect(results).to include(hash_including(code => version_mismatch_msg))
          end
          it 'does NOT get UPDATED_DB_OBJECT message' do
            expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT))
            expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
          end
        end
      end

      context 'db update error' do
        context 'ActiveRecordError' do
          let(:result_code) { PreservedObjectHandlerResults::DB_UPDATE_FAILED }
          let(:incoming_version) { 2 }
          let(:results) do
            allow(Rails.logger).to receive(:log)
            # FIXME: couldn't figure out how to put next line into its own test
            expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{db_update_failed_prefix_regex_escaped}/)

            po = instance_double("PreservedObject")
            allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
            pc = instance_double("PreservedCopy")
            allow(PreservedCopy).to receive(:find_by).and_return(pc)
            allow(pc).to receive(:version).and_return(2)
            allow(pc).to receive(:status)
            allow(pc).to receive(:last_audited=)
            allow(pc).to receive(:last_checked_on_storage=)
            allow(pc).to receive(:changed?).and_return(true)
            allow(pc).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
            allow(po).to receive(:current_version).and_return(2)
            po_handler.check_existence
          end

          context 'transaction is rolled back' do
            it 'does something' do
              fail 'we need to write test for checking rolled back transaction'
            end
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

      it 'calls PreservedCopy.save! (but not PreservedObject.save!) if the existing record is altered' do
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        status = PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:save!)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:status).and_return(status)
        allow(pc).to receive(:last_audited=)
        allow(pc).to receive(:last_checked_on_storage=)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:save!)
        po_handler.check_existence
        expect(po).not_to have_received(:save!)
        expect(pc).to have_received(:save!)
      end
      it 'calls PreservedCopy.touch (but not PreservedObject.touch) if the existing record is NOT altered' do
        po_handler = described_class.new(druid, 1, 1, ep)
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:touch)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:last_audited=)
        allow(pc).to receive(:last_checked_on_storage=)
        allow(pc).to receive(:changed?).and_return(false)
        allow(pc).to receive(:touch)
        po_handler.check_existence
        expect(po).not_to have_received(:touch)
        expect(pc).to have_received(:touch)
      end
      it 'logs a debug message' do
        msg = "check_existence #{druid} called"
        allow(Rails.logger).to receive(:debug)
        po_handler.check_existence
        expect(Rails.logger).to have_received(:debug).with(msg)
      end
    end

    context 'object not in db' do
      # FIXME: if requirements change to a single message for "object does not exist" and "created object"
      #  then this will no longer be correct?
      # NOTE: this pertains to PreservedObject
      it_behaves_like 'druid not in catalog', :check_existence

      # FIXME: if requirements change to a single message for "object does not exist" and "created object"
      #  then this will no longer be correct?
      it_behaves_like 'PreservedCopy does not exist', :check_existence

      # it 'stops processing if there is no PreservedCopy' do
      #   druid = 'nd000lm0000'
      #   diff_ep = Endpoint.create!(
      #     endpoint_name: 'diff_endpoint',
      #     endpoint_type: Endpoint.default_storage_root_endpoint_type,
      #     endpoint_node: 'localhost',
      #     storage_location: 'blah',
      #     recovery_cost: 1
      #   )
      #   PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
      #   po_handler = described_class.new(druid, 3, incoming_size, diff_ep)
      #   results = po_handler.check_existence
      #   code = PreservedObjectHandlerResults::OBJECT_DOES_NOT_EXIST
      #   exp_str = "ActiveRecord::RecordNotFound: Couldn't find PreservedCopy> db object does not exist"
      #   expect(results).to include(a_hash_including(code => a_string_matching(exp_str)))
      #   expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
      # end

      context 'adds to catalog after validation' do
        it 'does something' do
          fail 'need tests showing validation and create happen when object not in db'
        end
      end
    end
  end
end
