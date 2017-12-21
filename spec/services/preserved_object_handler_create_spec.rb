require 'rails_helper'
require 'services/shared_examples_preserved_object_handler'

RSpec.describe PreservedObjectHandler do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' }
  let(:ep) { Endpoint.find_by(storage_location: storage_dir) }
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{ep.endpoint_name})" }
  let(:db_update_failed_prefix_regex_escaped) { Regexp.escape("#{exp_msg_prefix} db update failed") }
  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, ep) }
  let(:exp_msg) { "#{exp_msg_prefix} added object to db as it did not exist" }

  describe '#create' do
    it 'creates the preserved object and preserved copy' do
      po_args = {
        druid: druid,
        current_version: incoming_version,
        preservation_policy_id: PreservationPolicy.default_policy_id
      }
      pc_args = {
        preserved_object: an_instance_of(PreservedObject), # TODO: ensure we got the preserved object that we expected
        version: incoming_version,
        size: incoming_size,
        endpoint: ep,
        status: PreservedCopy::VALIDITY_UNKNOWN_STATUS # NOTE: ensuring this particular status
        # NOTE: lack of validation timestamps here
      }

      expect(PreservedObject).to receive(:create!).with(po_args).and_call_original
      expect(PreservedCopy).to receive(:create!).with(pc_args).and_call_original
      po_handler.create
    end

    it_behaves_like 'attributes validated', :create

    context 'object already exists' do
      let!(:exp_msg) { "#{exp_msg_prefix} PreservedObject db object already exists" }

      it 'logs an error' do
        po_handler.create
        expect(Rails.logger).to receive(:log).with(Logger::ERROR, exp_msg)
        new_po_handler = described_class.new(druid, incoming_version, incoming_size, ep)
        new_po_handler.create
      end
    end

    context 'db update error' do
      context 'ActiveRecordError' do
        let(:result_code) { PreservedObjectHandlerResults::DB_UPDATE_FAILED }
        let(:results) do
          allow(Rails.logger).to receive(:log)
          # FIXME: couldn't figure out how to put next line into its own test
          expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{db_update_failed_prefix_regex_escaped}/)

          po = instance_double("PreservedObject")
          allow(PreservedObject).to receive(:create!).with(hash_including(druid: druid))
                                                     .and_raise(ActiveRecord::ActiveRecordError, 'foo')
          allow(po).to receive(:destroy) # for after() cleanup calls
          po_handler.create
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
          it 'does NOT get CREATED_NEW_OBJECT message' do
            expect(results).not_to include(hash_including(PreservedObjectHandlerResults::CREATED_NEW_OBJECT))
          end
        end
      end

      it "rolls back pres object creation if the pres copy can't be created (e.g. due to DB constraint violation)" do
        # so that pres copy creation fails, thus forcing the transaction to be rolled back
        allow(PreservedCopy).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
        po_handler.create
        expect(PreservedObject.where(druid: druid)).not_to exist
      end
    end

    context 'returns' do
      let!(:result) { po_handler.create }

      it '1 result' do
        expect(result).to be_an_instance_of Array
        expect(result.size).to eq 1
      end
      it 'CREATED_NEW_OBJECT result' do
        code = PreservedObjectHandlerResults::CREATED_NEW_OBJECT
        expect(result).to include(a_hash_including(code => exp_msg))
      end
    end
  end

  describe '#create_after_validation' do
    let(:valid_druid) { 'bp628nk4868' }
    let(:storage_dir) { 'spec/fixtures/storage_root02/moab_storage_trunk' }

    it_behaves_like 'attributes validated', :create_after_validation

    context 'sets validation timestamps' do
      let(:t) { Time.current }
      let(:ep) { Endpoint.find_by(storage_location: storage_dir) }
      let(:po_db_obj) { PreservedObject.find_by(druid: valid_druid) }
      let(:pc_db_obj) { PreservedCopy.find_by(preserved_object: po_db_obj) }
      let(:results) do
        po_handler = described_class.new(valid_druid, incoming_version, incoming_size, ep)
        po_handler.create_after_validation
      end

      before { results }

      it "sets last_moab_validation with current time" do
        expect(pc_db_obj.last_moab_validation).to be_within(10).of(t)
      end
      it "sets last_version_audit with current time" do
        expect(pc_db_obj.last_version_audit).to be_within(10).of(t)
      end
    end

    it 'creates the preserved object and preserved copy when there are no validation errors' do
      po_args = {
        druid: valid_druid,
        current_version: incoming_version,
        preservation_policy_id: PreservationPolicy.default_policy_id
      }
      pc_args = {
        preserved_object: an_instance_of(PreservedObject), # TODO: ensure we got the preserved object that we expected
        version: incoming_version,
        size: incoming_size,
        endpoint: ep,
        status: PreservedCopy::OK_STATUS, # NOTE ensuring this particular status
        last_moab_validation: an_instance_of(ActiveSupport::TimeWithZone),
        last_version_audit: an_instance_of(ActiveSupport::TimeWithZone)
      }

      expect(PreservedObject).to receive(:create!).with(po_args).and_call_original
      expect(PreservedCopy).to receive(:create!).with(pc_args).and_call_original
      po_handler = described_class.new(valid_druid, incoming_version, incoming_size, ep)
      po_handler.create_after_validation
    end

    it 'calls Stanford::StorageObjectValidator.validation_errors' do
      mock_sov = instance_double(Stanford::StorageObjectValidator)
      expect(mock_sov).to receive(:validation_errors).and_return([])
      allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
      po_handler = described_class.new(valid_druid, incoming_version, incoming_size, ep)
      po_handler.create_after_validation
    end

    context 'when moab is invalid' do
      let(:storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
      let(:ep) { Endpoint.find_by(storage_location: storage_dir) }
      let(:invalid_druid) { 'xx000xx0000' }
      let(:exp_msg_prefix) { "PreservedObjectHandler(#{invalid_druid}, #{incoming_version}, #{incoming_size}, #{ep.endpoint_name})" }

      # here we add the storage root with the invalid moab to the Endpoints table
      before do
        Endpoint.find_or_create_by!(endpoint_name: 'bad_fixture_dir') do |endpoint|
          endpoint.endpoint_type = Endpoint.default_storage_root_endpoint_type
          endpoint.endpoint_node = Settings.endpoints.storage_root_defaults.endpoint_node
          endpoint.storage_location = storage_dir
          endpoint.recovery_cost = Settings.endpoints.storage_root_defaults.recovery_cost
        end
      end

      it 'creates preserved object as well as preserved copy object with "invalid_moab" status' do
        po_args = {
          druid: invalid_druid,
          current_version: incoming_version,
          preservation_policy_id: PreservationPolicy.default_policy_id
        }
        pc_args = {
          preserved_object: an_instance_of(PreservedObject), # TODO: ensure we got the preserved object that we expected
          version: incoming_version,
          size: incoming_size,
          endpoint: ep,
          status: PreservedCopy::INVALID_MOAB_STATUS, # NOTE ensuring this particular status
          last_moab_validation: an_instance_of(ActiveSupport::TimeWithZone),
          last_version_audit: an_instance_of(ActiveSupport::TimeWithZone)
        }

        expect(PreservedObject).to receive(:create!).with(po_args).and_call_original
        expect(PreservedCopy).to receive(:create!).with(pc_args).and_call_original
        po_handler = described_class.new(invalid_druid, incoming_version, incoming_size, ep)
        po_handler.create_after_validation
      end

      context 'db update error' do
        context 'ActiveRecordError' do
          let(:result_code) { PreservedObjectHandlerResults::DB_UPDATE_FAILED }
          let(:results) do
            allow(Rails.logger).to receive(:log)
            # FIXME: couldn't figure out how to put next line into its own test
            expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{db_update_failed_prefix_regex_escaped}/)

            po = instance_double("PreservedObject")
            allow(PreservedObject).to receive(:create!).with(hash_including(druid: invalid_druid))
                                                       .and_raise(ActiveRecord::ActiveRecordError, 'foo')
            allow(po).to receive(:destroy) # for after() cleanup calls
            po_handler = described_class.new(invalid_druid, incoming_version, incoming_size, ep)
            po_handler.create_after_validation
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

    describe '#moab_validation_errors logging' do
      it "does not log moab validation errors when moab is valid" do
        po_handler = described_class.new(valid_druid, incoming_version, incoming_size, ep)
        exp_msg_prefix = "PreservedObjectHandler(#{valid_druid}, #{incoming_version}, #{incoming_size}, #{ep.endpoint_name})"
        no_errors = "#{exp_msg_prefix} added object to db as it did not exist"
        expect(Rails.logger).to receive(:log).with(Logger::INFO, no_errors)
        po_handler.create_after_validation
      end
      it "logs moab validation errors when moab is invalid" do
        invalid_druid = 'yy000yy0000'
        po_handler = described_class.new(invalid_druid, incoming_version, incoming_size, ep)
        exp_msg_prefix = "PreservedObjectHandler(#{invalid_druid}, #{incoming_version}, #{incoming_size}, #{ep.endpoint_name})"
        allow(Rails.logger).to receive(:log)
        errors = "#{exp_msg_prefix} Invalid moab, validation errors: [\"Missing directory: [\\\"manifests\\\"] Version: v0001\"]"
        expect(Rails.logger).to receive(:log).with(Logger::ERROR, errors)
        po_handler.create_after_validation
      end
    end

    context 'returns' do
      let(:valid_druid) { 'bp628nk4868' }
      let(:storage_dir) { 'spec/fixtures/storage_root02/moab_storage_trunk' }
      let(:ep) { Endpoint.find_by(storage_location: storage_dir) }

      let(:po_handler) { described_class.new(valid_druid, incoming_version, incoming_size, ep) }

      let!(:result) { po_handler.create_after_validation }
      let(:exp_msg_prefix) { "PreservedObjectHandler(#{valid_druid}, #{incoming_version}, #{incoming_size}, #{ep.endpoint_name})" }

      it '1 result' do
        expect(result).to be_an_instance_of Array
        expect(result.size).to eq 1
      end
      it 'CREATED_NEW_OBJECT result' do
        code = PreservedObjectHandlerResults::CREATED_NEW_OBJECT
        expect(result).to include(a_hash_including(code => exp_msg))
      end
    end
  end
end
