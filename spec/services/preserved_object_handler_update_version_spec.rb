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
          preserved_object: po, # TODO: see if we got the preserved object that we expected
          version: po.current_version,
          size: 1,
          endpoint: ep,
          status: PreservedCopy.statuses[:expected_version_not_found_online]
        )
      end

      context 'incoming version newer than catalog versions (both) (happy path)' do
        it "updates PreservedCopy with incoming version" do
          expect(pc.version).to eq 2
          po_handler.update_version
          expect(pc.reload.version).to be > 2
          expect(pc.reload.version).to eq incoming_version
        end
        it "updates PreservedObject with incoming version" do
          expect(po.current_version).to eq 2
          po_handler.update_version
          expect(po.reload.current_version).to be > 2
          expect(po.reload.current_version).to eq incoming_version
        end
        it 'updates PreservedCopy size if supplied' do
          expect(pc.size).to eq 1
          po_handler.update_version
          expect(pc.reload.size).to eq incoming_size
        end
        it 'PreservedCopy retains old size if incoming size is nil' do
          expect(pc.size).to eq 1
          po_handler = described_class.new(druid, incoming_version, nil, ep)
          po_handler.update_version
          expect(pc.reload.size).to eq 1
        end
        it 'does not update status of PreservedCopy' do
          # TODO: not clear what to do here;  it's not 'ok' if we didn't validate ...
          expect(PreservedCopy.statuses[pc.status]).to eq PreservedCopy.statuses[:expected_version_not_found_online]
          po_handler.update_version
          expect(PreservedCopy.statuses[pc.reload.status]).to eq PreservedCopy.statuses[:expected_version_not_found_online]
        end
        it 'does not update PreservedCopy last_audited field' do
          orig_timestamp = pc.last_audited
          po_handler.update_version
          expect(pc.reload.last_audited).to eq orig_timestamp
        end
        it 'does not update PreservedCopy last_checked_on_storage' do
          orig_timestamp = pc.last_checked_on_storage
          po_handler.update_version
          expect(pc.reload.last_checked_on_storage).to eq orig_timestamp
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
            code = PreservedObjectHandler::ARG_VERSION_GREATER_THAN_DB_OBJECT
            expect(results).to include(a_hash_including(code => version_gt_pc_msg))
            expect(results).to include(a_hash_including(code => version_gt_po_msg))
          end
          it "UPDATED_DB_OBJECT results" do
            code = PreservedObjectHandler::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_msg))
            expect(results).to include(a_hash_including(code => updated_po_db_msg))
          end
        end
      end

      RSpec.shared_examples 'unexpected version' do |incoming_version|
        let(:po_handler) { described_class.new(druid, incoming_version, 1, ep) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, 1, #{ep})" }
        let(:version_msg_prefix) { "#{exp_msg_prefix} incoming version (#{incoming_version})" }
        let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to PreservedCopy db version; ERROR!" }

        it "PreservedCopy version stays the same" do
          pcv = pc.version
          po_handler.update_version
          expect(pc.reload.version).to eq pcv
        end
        it "PreservedObject current_version stays the same" do
          pocv = po.current_version
          po_handler.update_version
          expect(po.reload.current_version).to eq pocv
        end
        it "PreservedCopy size stays the same" do
          expect(pc.size).to eq 1
          po_handler.update_version
          expect(pc.reload.size).to eq 1
        end
        it 'does not update PreservedCopy last_audited field' do
          orig_timestamp = pc.last_audited
          po_handler.update_version
          expect(pc.reload.last_audited).to eq orig_timestamp
        end
        it 'does not update PreservedCopy last_checked_on_storage' do
          orig_timestamp = pc.last_checked_on_storage
          po_handler.update_version
          expect(pc.reload.last_checked_on_storage).to eq orig_timestamp
        end
        it 'does not update status of PreservedCopy' do
          orig_status = pc.status
          po_handler.update_version
          expect(pc.reload.status).to eq orig_status
        end
        it "logs at error level" do
          expect(Rails.logger).to receive(:log).with(Logger::ERROR, unexpected_version_msg)
          expect(Rails.logger).not_to receive(:log).with(Logger::INFO, updated_pc_db_timestamp_msg)
          expect(Rails.logger).not_to receive(:log).with(Logger::ERROR, updated_po_db_timestamp_msg)
          expect(Rails.logger).not_to receive(:log).with(Logger::INFO, updated_status_msg_regex)
          po_handler.update_version
        end

        context 'returns' do
          let!(:results) { po_handler.update_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '3 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 3
          end
          it 'UNEXPECTED_VERSION result' do
            code = PreservedObjectHandler::UNEXPECTED_VERSION
            expect(results).to include(a_hash_including(code => unexpected_version_msg))
          end
          it 'specific version results' do
            codes = [
              PreservedObjectHandler::VERSION_MATCHES,
              PreservedObjectHandler::ARG_VERSION_GREATER_THAN_DB_OBJECT,
              PreservedObjectHandler::ARG_VERSION_LESS_THAN_DB_OBJECT
            ]
            obj_version_results = results.select { |r| codes.include?(r.keys.first) }
            msgs = obj_version_results.map { |r| r.values.first }
            expect(msgs).to include(a_string_matching("PreservedObject"))
            expect(msgs).to include(a_string_matching("PreservedCopy"))
          end
          it "no UPDATED_DB_OBJECT_TIMESTAMP_ONLY results" do
            expect(results).not_to include(a_hash_including(PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
          end
          it 'no PC_STATUS_CHANGED result' do
            expect(results).not_to include(a_hash_including(PreservedObjectHandler::PC_STATUS_CHANGED))
          end
        end
      end

      context 'PreservedCopy and PreservedObject versions do not match' do
        before do
          @pc.version = @pc.version + 1
          @pc.save!
        end

        it_behaves_like 'unexpected version', 8
      end

      context 'incoming version same as catalog versions (both)' do
        it_behaves_like 'unexpected version', 2
      end

      context 'incoming version lower than catalog versions (both)' do
        it_behaves_like 'unexpected version', 1
      end

      context 'db update error' do
        let(:result_code) { PreservedObjectHandler::DB_UPDATE_FAILED }

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
              allow(pc).to receive(:status).and_return(PreservedCopy.statuses[:ok])
              allow(pc).to receive(:status=)
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
                expect(results).not_to include(hash_including(PreservedObjectHandler::UPDATED_DB_OBJECT))
                expect(results).not_to include(hash_including(PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
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
              allow(pc).to receive(:status).and_return(PreservedCopy.statuses[:ok])
              allow(pc).to receive(:status=)
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
                expect(results).not_to include(hash_including(PreservedObjectHandler::UPDATED_DB_OBJECT))
                expect(results).not_to include(hash_including(PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
              end
            end
          end
        end
      end

      it 'calls PreservedObject.save! and PreservedCopy.save! if the existing record is altered' do
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
        allow(pc).to receive(:status).and_return(PreservedCopy.statuses[:ok])
        allow(pc).to receive(:status=)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:save!)
        po_handler.update_version
        expect(po).to have_received(:save!)
        expect(pc).to have_received(:save!)
      end

      it 'does not call PreservedObject.touch or PreservedCopy.touch if the existing record is NOT altered' do
        po_handler = described_class.new(druid, 1, 1, ep)
        po = instance_double(PreservedObject)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:changed?).and_return(false)
        allow(po).to receive(:touch)
        pc = instance_double(PreservedCopy)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:changed?).and_return(false)
        allow(pc).to receive(:touch)
        po_handler.update_version
        expect(po).not_to have_received(:touch)
        expect(pc).not_to have_received(:touch)
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
        let(:po) { PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy) }
        let(:pc) do
          PreservedCopy.create!(
            preserved_object: po, # TODO: see if we got the preserved object that we expected
            version: po.current_version,
            size: 1,
            endpoint: ep,
            status: PreservedCopy.statuses[:ok],
            last_audited: Time.current.to_i,
            last_checked_on_storage: Time.current
          )
        end

        it 'updates PreservedCopy last_audited' do
          orig_timestamp = pc.last_audited
          sleep 1 # last_audited is bigint, and granularity is second, not fraction thereof
          po_handler.update_version_after_validation
          expect(pc.reload.last_audited).to be > orig_timestamp
        end
        it 'updates PreservedCopy last_checked_on_storage' do
          orig_timestamp = pc.last_checked_on_storage
          po_handler.update_version_after_validation
          expect(pc.reload.last_checked_on_storage).to be > orig_timestamp
        end

        it 'calls #update_online_version with validated = true and PreservedCopy.statuses[:ok]' do
          expect(po_handler).to receive(:update_online_version).with(true, PreservedCopy.statuses[:ok]).and_call_original
          po_handler.update_version_after_validation
          skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
        end

        it 'updates PreservedCopy status to "ok" if it was "moab_invalid"' do
          pc.status = PreservedCopy.statuses[:invalid_moab]
          pc.save!
          po_handler.update_version_after_validation
          expect(PreservedCopy.statuses[pc.reload.status]).to eq PreservedCopy.statuses[:ok]
        end
      end

      context 'when moab is invalid' do
        let(:druid) { 'xx000xx0000' }
        let(:storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
        let(:ep) { Endpoint.find_by(storage_location: storage_dir) }

        before do
          # add storage root with the invalid moab to the Endpoints table
          Endpoint.find_or_create_by!(endpoint_name: 'bad_fixture_dir') do |endpoint|
            endpoint.endpoint_type = Endpoint.default_storage_root_endpoint_type
            endpoint.endpoint_node = Settings.endpoints.storage_root_defaults.endpoint_node
            endpoint.storage_location = storage_dir
            endpoint.recovery_cost = Settings.endpoints.storage_root_defaults.recovery_cost
          end
          # these need to be in before loop so it happens before each context below
          PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
          PreservedCopy.create!(
            preserved_object: po, # TODO: see if we got the preserved object that we expected
            version: po.current_version,
            size: 1,
            endpoint: ep,
            status: PreservedCopy.statuses[:ok],
            last_audited: Time.current.to_i,
            last_checked_on_storage: Time.current
          )
        end

        it 'updates PreservedCopy last_audited' do
          orig_timestamp = pc.last_audited
          sleep 1 # last_audited is bigint, and granularity is second, not fraction thereof
          po_handler.update_version_after_validation
          expect(pc.reload.last_audited).to be > orig_timestamp
        end
        it 'updates PreservedCopy last_checked_on_storage' do
          orig_timestamp = pc.last_checked_on_storage
          po_handler.update_version_after_validation
          expect(pc.reload.last_checked_on_storage).to be > orig_timestamp
        end
        it 'ensures PreservedCopy status is invalid' do
          pc.status = PreservedCopy.statuses[:ok]
          pc.save!
          po_handler.update_version_after_validation
          expect(PreservedCopy.statuses[pc.reload.status]).to eq PreservedCopy.statuses[:invalid_moab]
        end

        it 'logs a debug message' do
          msg = "update_version_after_validation #{druid} called"
          allow(Rails.logger).to receive(:debug)
          po_handler.update_version_after_validation
          expect(Rails.logger).to have_received(:debug).with(msg)
        end

        it 'calls PreservedObject.save! and PreservedCopy.save! if the existing record is altered' do
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
          allow(pc).to receive(:status).and_return(PreservedCopy.statuses[:ok])
          allow(pc).to receive(:status=)
          allow(pc).to receive(:last_audited=)
          allow(pc).to receive(:last_checked_on_storage=)
          allow(pc).to receive(:changed?).and_return(true)
          allow(pc).to receive(:save!)
          allow(po_handler).to receive(:moab_validation_errors).and_return(['foo'])
          po_handler.update_version_after_validation
          expect(po).to have_received(:save!)
          expect(pc).to have_received(:save!)
        end

        it 'does not call PreservedObject.touch and PreservedCopy.touch if the existing record is NOT altered' do
          po_handler = described_class.new(druid, 1, 1, ep)
          po = instance_double(PreservedObject)
          allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
          allow(po).to receive(:current_version).and_return(1)
          allow(po).to receive(:changed?).and_return(false)
          allow(po).to receive(:touch)
          pc = instance_double(PreservedCopy)
          allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
          allow(pc).to receive(:version).and_return(1)
          allow(pc).to receive(:endpoint).with(ep)
          allow(pc).to receive(:status).and_return(PreservedCopy.statuses[:ok])
          allow(pc).to receive(:status=)
          allow(pc).to receive(:last_audited=)
          allow(pc).to receive(:last_checked_on_storage=)
          allow(pc).to receive(:changed?).and_return(false)
          allow(pc).to receive(:touch)
          po_handler.update_version_after_validation
          expect(po).not_to have_received(:touch)
          expect(pc).not_to have_received(:touch)
        end

        context 'incoming version newer than catalog versions (both) (happy path)' do
          it 'calls #update_online_version with validated = true and PreservedCopy.statuses[:invalid_moab]' do
            expect(po_handler).to receive(:update_online_version).with(true, PreservedCopy.statuses[:invalid_moab]).and_call_original
            po_handler.update_version_after_validation
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end
        end

        RSpec.shared_examples 'unexpected version with validation' do |incoming_version|
          let(:po_handler) { described_class.new(druid, incoming_version, 1, ep) }
          let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, 1, #{ep})" }
          let(:version_msg_prefix) { "#{exp_msg_prefix} incoming version (#{incoming_version})" }
          let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to PreservedCopy db version; ERROR!" }

          it "PreservedCopy version stays the same" do
            pcv = pc.version
            po_handler.update_version_after_validation
            expect(pc.reload.version).to eq pcv
          end
          it "PreservedObject current_version stays the same" do
            pocv = po.current_version
            po_handler.update_version_after_validation
            expect(po.reload.current_version).to eq pocv
          end
          it "PreservedCopy size stays the same" do
            expect(pc.size).to eq 1
            po_handler.update_version_after_validation
            expect(pc.reload.size).to eq 1
          end
          it 'updates PreservedCopy last_audited field' do
            orig_timestamp = pc.last_audited
            sleep 1 # last_audited is bigint, and granularity is second, not fraction thereof
            po_handler.update_version_after_validation
            expect(pc.reload.last_audited).to be > orig_timestamp
          end
          it 'updates PreservedCopy last_checked_on_storage' do
            orig_timestamp = pc.last_checked_on_storage
            po_handler.update_version_after_validation
            expect(pc.reload.last_checked_on_storage).to be > orig_timestamp
          end
          it 'ensures status of PreservedCopy is invalid' do
            pc.status = PreservedCopy.statuses[:ok]
            pc.save!
            po_handler.update_version_after_validation
            expect(PreservedCopy.statuses[pc.reload.status]).to eq PreservedCopy.statuses[:invalid_moab]
          end
          it "logs at error level" do
            expect(Rails.logger).to receive(:log).with(Logger::ERROR, unexpected_version_msg)
            expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
            expect(Rails.logger).not_to receive(:log).with(Logger::ERROR, updated_po_db_msg)
            expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_status_msg_regex)
            po_handler.update_version_after_validation
          end

          context 'returns' do
            let!(:results) { po_handler.update_version_after_validation }

            # results = [result1, result2]
            # result1 = {response_code: msg}
            # result2 = {response_code: msg}
            it '5 results' do
              expect(results).to be_an_instance_of Array
              expect(results.size).to eq 5
            end
            it 'UNEXPECTED_VERSION result' do
              code = PreservedObjectHandler::UNEXPECTED_VERSION
              expect(results).to include(a_hash_including(code => unexpected_version_msg))
            end
            it 'specific version results' do
              codes = [
                PreservedObjectHandler::VERSION_MATCHES,
                PreservedObjectHandler::ARG_VERSION_GREATER_THAN_DB_OBJECT,
                PreservedObjectHandler::ARG_VERSION_LESS_THAN_DB_OBJECT
              ]
              obj_version_results = results.select { |r| codes.include?(r.keys.first) }
              msgs = obj_version_results.map { |r| r.values.first }
              expect(msgs).to include(a_string_matching("PreservedObject"))
              expect(msgs).to include(a_string_matching("PreservedCopy"))
            end
            it "PreservedCopy UPDATED_DB_OBJECT results" do
              code = PreservedObjectHandler::UPDATED_DB_OBJECT
              expect(results).to include(a_hash_including(code => updated_pc_db_msg))
            end
            it 'PC_STATUS_CHANGED result' do
              expect(results).to include(a_hash_including(PreservedObjectHandler::PC_STATUS_CHANGED => updated_status_msg_regex))
            end
          end
        end

        context 'PreservedCopy and PreservedObject versions do not match' do
          before do
            pc.version = pc.version + 1
            pc.save!
          end

          it_behaves_like 'unexpected version with validation', 8
        end

        context 'incoming version same as catalog versions (both)' do
          it_behaves_like 'unexpected version with validation', 2
        end

        context 'incoming version lower than catalog versions (both)' do
          it_behaves_like 'unexpected version with validation', 1
        end

        context 'db update error' do
          let(:result_code) { PreservedObjectHandler::DB_UPDATE_FAILED }

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
                allow(pc).to receive(:status).and_return(PreservedCopy.statuses[:ok])
                allow(pc).to receive(:status=)
                allow(pc).to receive(:last_audited=)
                allow(pc).to receive(:last_checked_on_storage=)
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
                allow(pc).to receive(:last_audited=)
                allow(pc).to receive(:last_checked_on_storage=)
                allow(pc).to receive(:status).and_return(PreservedCopy.statuses[:ok])
                allow(pc).to receive(:status=)
                allow(pc).to receive(:changed?).and_return(true)
                allow(pc).to receive(:save!)
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
