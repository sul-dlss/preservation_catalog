require 'rails_helper'
require 'services/shared_examples_preserved_object_handler'

RSpec.describe PreservedObjectHandler do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' } # we are just going to assume the first rails storage root
  let(:ep) { Endpoint.find_by(storage_location: storage_dir) }
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{storage_dir})" }
  let(:db_update_failed_prefix_regex_escaped) { Regexp.escape("#{exp_msg_prefix} db update failed") }
  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, storage_dir) }

  describe '#create' do
    let!(:exp_msg) { "#{exp_msg_prefix} added object to db as it did not exist" }

    it 'creates the preserved object and preserved copy' do
      po_args = {
        druid: druid,
        current_version: incoming_version,
        preservation_policy: PreservationPolicy.default_preservation_policy
      }
      pc_args = {
        preserved_object: an_instance_of(PreservedObject), # TODO: see if we got the preserved object that we expected
        version: incoming_version,
        size: incoming_size,
        endpoint: ep,
        status: Status.default_status
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
        po_handler.create
      end
    end

    context 'db update error' do
      context 'ActiveRecordError' do
        let(:result_code) { PreservedObjectHandler::DB_UPDATE_FAILED }
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
        end
      end
    end

    context 'returns' do
      let!(:result) { po_handler.create }

      it '1 result' do
        expect(result).to be_an_instance_of Array
        expect(result.size).to eq 1
      end
      it 'CREATED_NEW_OBJECT result' do
        code = PreservedObjectHandler::CREATED_NEW_OBJECT
        expect(result).to include(a_hash_including(code => exp_msg))
      end
    end
  end
end
