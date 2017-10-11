require 'rails_helper'

RSpec.describe PreservedObjectHandler do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' } # we are just going to assume the first rails storage root

  describe '#initialize' do
    it 'sets druid' do
      po_handler = described_class.new(druid, incoming_version, nil, storage_dir)
      expect(po_handler.druid).to eq druid
    end
    context 'sets incoming_version' do
      { # passed value => expected parsed value
        6 => 6,
        0 => 0,
        -1 => -1,
        '6' => 6,
        '006' => 6,
        'v0006' => 6,
        '0' => 0,
        '-666' => '-666',
        'vv001' => 'vv001',
        'asdf' => 'asdf'
      }.each do |k, v|
        it "by parsing '#{k}' to '#{v}'" do
          po_handler = described_class.new(druid, k, nil, storage_dir)
          expect(po_handler.incoming_version).to eq v
        end
      end
    end
    context 'sets incoming_size' do
      { # passed value => expected parsed value
        6 => 6,
        0 => 0,
        -1 => -1,
        '0' => 0,
        '6' => 6,
        '006' => 6,
        'v0006' => 'v0006',
        '-666' => '-666',
        'vv001' => 'vv001',
        'asdf' => 'asdf'
      }.each do |k, v|
        it "by parsing '#{k}' to '#{v}'" do
          po_handler = described_class.new(druid, nil, k, storage_dir)
          expect(po_handler.incoming_size).to eq v
        end
      end
    end
    it 'sets storage directory' do 
      po_handler = described_class.new(druid, incoming_version, nil, storage_dir)
      expect(po_handler.storage_dir).to eq storage_dir
    end
  end

  # describe '#update_or_create' do
  #   let!(:default_prez_policy) do
  #     PreservationPolicy.create!(preservation_policy_name: 'default',
  #                                archive_ttl: 604_800,
  #                                fixity_ttl: 604_800)
  #   end

  #   context 'logs errors and returns INVALID_ARGUMENTS if ActiveModel::Validations fail' do
  #     let(:bad_druid) { '666' }
  #     let(:bad_version) { 'vv666' }
  #     let(:bad_size) { '-666' }

  #     context 'returns' do
  #       let!(:result) do
  #         po_handler = described_class.new(bad_druid, bad_version, bad_size)
  #         po_handler.update_or_create
  #       end

  #       it '1 result' do
  #         expect(result).to be_an_instance_of Array
  #         expect(result.size).to eq 1
  #       end
  #       it 'INVALID_ARGUMENTS' do
  #         expect(result).to include(a_hash_including(PreservedObjectHandler::INVALID_ARGUMENTS))
  #       end
  #       context 'result message includes' do
  #         let(:msg) { result.first[PreservedObjectHandler::INVALID_ARGUMENTS] }
  #         let(:exp_msg_prefix) { "PreservedObjectHandler(#{bad_druid}, #{bad_version}, #{bad_size})" }

  #         it "prefix" do
  #           expect(msg).to match(Regexp.escape("#{exp_msg_prefix} encountered validation error(s): "))
  #         end
  #         it "druid error" do
  #           expect(msg).to match(/Druid is invalid/)
  #         end
  #         it "version error" do
  #           expect(msg).to match(/Incoming version is not a number/)
  #         end
  #         it "size error" do
  #           expect(msg).to match(/Incoming size must be greater than 0/)
  #         end
  #       end
  #     end
  #     it 'bad druid error is written to Rails log' do
  #       po_handler = described_class.new(bad_druid, incoming_version, incoming_size)
  #       err_msg = "PreservedObjectHandler(#{bad_druid}, #{incoming_version}, #{incoming_size}) encountered validation error(s): [\"Druid is invalid\"]"
  #       allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
  #       po_handler.update_or_create
  #       expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
  #     end
  #     it 'bad version error is written to Rails log' do
  #       po_handler = described_class.new(druid, bad_version, incoming_size)
  #       err_msg = "PreservedObjectHandler(#{druid}, #{bad_version}, #{incoming_size}) encountered validation error(s): [\"Incoming version is not a number\"]"
  #       allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
  #       po_handler.update_or_create
  #       expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
  #     end
  #     it 'bad size error is written to Rails log' do
  #       po_handler = described_class.new(druid, incoming_version, bad_size)
  #       err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{bad_size}) encountered validation error(s): [\"Incoming size must be greater than 0\"]"
  #       allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
  #       po_handler.update_or_create
  #       expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
  #     end
  #   end

  #   context 'druid in db' do
  #     before do
  #       po = PreservedObject.find_by(druid: druid)
  #       po.destroy if po
  #       PreservedObject.create!(druid: druid, current_version: 2, size: 1, preservation_policy: default_prez_policy)
  #     end
  #     after do
  #       po = PreservedObject.find_by(druid: druid)
  #       po.destroy if po
  #     end
  #     let(:po_handler) { described_class.new(druid, incoming_version, incoming_size) }
  #     let(:po) { PreservedObject.find_by(druid: druid) }

  #     context "incoming and db versions match" do
  #       let(:po_handler) { described_class.new(druid, 2, 1) }
  #       let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 2, 1)" }
  #       let(:version_matches_msg) { "#{exp_msg_prefix} incoming version (2) matches db version" }
  #       let(:updated_db_timestamp_msg) { "#{exp_msg_prefix} updated db timestamp only" }

  #       it "entry version stays the same" do
  #         expect(po.current_version).to eq 2
  #         po_handler.update_or_create
  #         expect(po.reload.current_version).to eq 2
  #       end
  #       it "entry size stays the same" do
  #         expect(po.size).to eq 1
  #         po_handler.update_or_create
  #         expect(po.reload.size).to eq 1
  #       end
  #       it "logs at info level" do
  #         allow(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_msg)
  #         allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_db_timestamp_msg)
  #         po_handler.update_or_create
  #         expect(Rails.logger).to have_received(:log).with(Logger::INFO, version_matches_msg)
  #         expect(Rails.logger).to have_received(:log).with(Logger::INFO, updated_db_timestamp_msg)
  #       end
  #       context 'returns' do
  #         let!(:results) { po_handler.update_or_create }

  #         # results = [result1, result2]
  #         # result1 = {response_code: msg}
  #         # result2 = {response_code: msg}
  #         it '2 results' do
  #           expect(results).to be_an_instance_of Array
  #           expect(results.size).to eq 2
  #         end
  #         it 'VERSION_MATCHES result' do
  #           result_msg = results.select { |r| r[PreservedObjectHandler::VERSION_MATCHES] }.first.values.first
  #           expect(result_msg).to match(Regexp.escape(version_matches_msg))
  #         end
  #         it "UPDATED_DB_OBJECT_TIMESTAMP_ONLY result" do
  #           result_msg = results.select { |r| r[PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY] }.first.values.first
  #           expect(result_msg).to match(Regexp.escape(updated_db_timestamp_msg))
  #         end
  #       end
  #     end

  #     context 'incoming version newer than db version' do
  #       let(:po_handler) { described_class.new(druid, incoming_version, incoming_size) }
  #       let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size})" }
  #       let(:version_gt_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than db version" }
  #       let(:updated_db_msg) { "#{exp_msg_prefix} db object updated" }

  #       it "updates entry with incoming version" do
  #         expect(po.current_version).to eq 2
  #         po_handler.update_or_create
  #         expect(po.reload.current_version).to eq incoming_version
  #       end
  #       it 'updates entry with size if included' do
  #         expect(po.size).to eq 1
  #         po_handler.update_or_create
  #         expect(po.reload.size).to eq incoming_size
  #       end
  #       it 'retains old size if incoming size is nil' do
  #         expect(po.size).to eq 1
  #         po_handler = described_class.new(druid, incoming_version, nil)
  #         po_handler.update_or_create
  #         expect(po.reload.size).to eq 1
  #       end
  #       it "logs at info level" do
  #         allow(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_msg)
  #         allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_db_msg)
  #         po_handler.update_or_create
  #         expect(Rails.logger).to have_received(:log).with(Logger::INFO, version_gt_msg)
  #         expect(Rails.logger).to have_received(:log).with(Logger::INFO, updated_db_msg)
  #       end
  #       context 'returns' do
  #         let!(:results) { po_handler.update_or_create }

  #         # results = [result1, result2]
  #         # result1 = {response_code: msg}
  #         # result2 = {response_code: msg}
  #         it '2 results' do
  #           expect(results).to be_an_instance_of Array
  #           expect(results.size).to eq 2
  #         end
  #         it 'ARG_VERSION_GREATER_THAN_DB_OBJECT result' do
  #           result_msg = results.select { |r| r[PreservedObjectHandler::ARG_VERSION_GREATER_THAN_DB_OBJECT] }.first.values.first
  #           expect(result_msg).to match(Regexp.escape(version_gt_msg))
  #         end
  #         it "UPDATED_DB_OBJECT result" do
  #           result_msg = results.select { |r| r[PreservedObjectHandler::UPDATED_DB_OBJECT] }.first.values.first
  #           expect(result_msg).to match(Regexp.escape(updated_db_msg))
  #         end
  #       end
  #     end

  #     context 'incoming version older than db version' do
  #       let(:po_handler) { described_class.new(druid, 1, 666) }
  #       let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 1, 666)" }
  #       let(:version_less_than_msg) { "#{exp_msg_prefix} incoming version (1) less than db version; ERROR!" }
  #       let(:updated_db_timestamp_msg) { "#{exp_msg_prefix} updated db timestamp only" }

  #       it "entry version stays the same" do
  #         expect(po.current_version).to eq 2
  #         po_handler.update_or_create
  #         expect(po.reload.current_version).to eq 2
  #       end
  #       it "entry size stays the same" do
  #         expect(po.size).to eq 1
  #         po_handler.update_or_create
  #         expect(po.reload.size).to eq 1
  #       end
  #       it "logs at error level" do
  #         allow(Rails.logger).to receive(:log).with(Logger::ERROR, version_less_than_msg)
  #         allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_db_timestamp_msg)
  #         po_handler.update_or_create
  #         expect(Rails.logger).to have_received(:log).with(Logger::ERROR, version_less_than_msg)
  #         expect(Rails.logger).to have_received(:log).with(Logger::INFO, updated_db_timestamp_msg)
  #       end
  #       context 'returns' do
  #         let!(:results) { po_handler.update_or_create }

  #         # results = [result1, result2]
  #         # result1 = {response_code: msg}
  #         # result2 = {response_code: msg}
  #         it '2 results' do
  #           expect(results).to be_an_instance_of Array
  #           expect(results.size).to eq 2
  #         end
  #         it 'ARG_VERSION_LESS_THAN_DB_OBJECT result' do
  #           result_msg = results.select { |r| r[PreservedObjectHandler::ARG_VERSION_LESS_THAN_DB_OBJECT] }.first.values.first
  #           expect(result_msg).to match(Regexp.escape(version_less_than_msg))
  #         end
  #         # FIXME: do we want to update timestamp if we found an error (ARG_VERSION_LESS_THAN_DB_OBJECT)
  #         it "UPDATED_DB_OBJECT_TIMESTAMP_ONLY result" do
  #           result_msg = results.select { |r| r[PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY] }.first.values.first
  #           expect(result_msg).to match(Regexp.escape(updated_db_timestamp_msg))
  #         end
  #       end
  #     end

  #     context 'db update error' do
  #       context 'ActiveRecordError' do
  #         let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size})" }
  #         let(:db_update_failed_prefix) { "#{exp_msg_prefix} db update failed" }
  #         let(:results) do
  #           allow(Rails.logger).to receive(:log)
  #           # FIXME: couldn't figure out how to put next line into its own test
  #           expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{Regexp.escape(db_update_failed_prefix)}/)

  #           po = instance_double("PreservedObject")
  #           allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
  #           allow(po).to receive(:current_version).and_return(1)
  #           allow(po).to receive(:current_version=).with(incoming_version)
  #           allow(po).to receive(:size=).with(incoming_size)
  #           allow(po).to receive(:changed?).and_return(true)
  #           allow(po).to receive(:save).and_raise(ActiveRecord::ActiveRecordError, 'foo')
  #           allow(po).to receive(:destroy) # for after() cleanup calls
  #           po_handler.update_or_create
  #         end

  #         it 'DB_UPDATED_FAILED error' do
  #           expect(results).to include(a_hash_including(PreservedObjectHandler::DB_UPDATE_FAILED))
  #         end
  #         context 'error message' do
  #           let(:result_msg) { results.select { |r| r[PreservedObjectHandler::DB_UPDATE_FAILED] }.first.values.first }

  #           it 'prefix' do
  #             expect(result_msg).to match(Regexp.escape(db_update_failed_prefix))
  #           end
  #           it 'specific exception raised' do
  #             expect(result_msg).to match(Regexp.escape('ActiveRecord::ActiveRecordError'))
  #           end
  #           it "exception's message" do
  #             expect(result_msg).to match(Regexp.escape('foo'))
  #           end
  #         end
  #       end
  #     end

  #     it 'calls PreservedObject.save if the existing record is altered' do
  #       po = instance_double(PreservedObject)
  #       allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
  #       allow(po).to receive(:current_version).and_return(1)
  #       allow(po).to receive(:current_version=).with(incoming_version)
  #       allow(po).to receive(:size=).with(incoming_size)
  #       allow(po).to receive(:changed?).and_return(true)
  #       allow(po).to receive(:save)
  #       po_handler.update_or_create
  #       expect(po).to have_received(:save)

  #       allow(po).to receive(:destroy)
  #     end
  #     it 'calls PreservedObject.touch if the existing record is NOT altered' do
  #       po_handler = described_class.new(druid, 1, 1)
  #       po = instance_double(PreservedObject)
  #       allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
  #       allow(po).to receive(:current_version).and_return(1)
  #       allow(po).to receive(:changed?).and_return(false)
  #       allow(po).to receive(:touch)
  #       po_handler.update_or_create
  #       expect(po).to have_received(:touch)

  #       allow(po).to receive(:destroy)
  #     end
  #     it 'logs a debug message' do
  #       msg = "update #{druid} called and object exists"
  #       allow(Rails.logger).to receive(:debug)
  #       po_handler.update_or_create
  #       expect(Rails.logger).to have_received(:debug).with(msg)
  #     end
  #   end
  # end
  
  describe '#create' do
    let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, storage_dir) }
    let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{storage_dir})" }
    let!(:exp_msg) { "#{exp_msg_prefix} added object to db as it did not exist"  }
    it 'creates the preserved object and preservation copy' do 
      args = {
          druid: druid,
          current_version: incoming_version,
          size: incoming_size,
          preservation_policy: PreservationPolicy.default_preservation_policy,
      }
      args2 = {
          preserved_object: an_instance_of(PreservedObject), # TODO see if we got the preserved object that we expected
          current_version: incoming_version,
          last_audited: nil,
          endpoint: Endpoint.find_by(storage_location: storage_dir),
          status: Status.find_by(status_text: "ok"), # TODO find status default message
          last_checked_on_storage: nil # TODO nill for now, figure out how to use Time.now / ask devs
      }

      allow(PreservedObject).to receive(:create!).with(args).and_call_original
      allow(PreservationCopy).to receive(:create).with(args2).and_call_original
      po_handler.create
      expect(PreservedObject).to have_received(:create!).with(args)
      expect(PreservationCopy).to have_received(:create).with(args2)
    end
    context 'object already exists' do
      let!(:exp_msg) { "#{exp_msg_prefix} db object already exists" }
      it 'logs an error' do
        po_handler.create
        allow(Rails.logger).to receive(:log).with(Logger::ERROR, exp_msg)
        po_handler.create
        expect(Rails.logger).to have_received(:log).with(Logger::ERROR, exp_msg)
      end
    end
    context 'returns' do
      let!(:result) { po_handler.create }

      it '1 result' do
        expect(result).to be_an_instance_of Array
        expect(result.size).to eq 1
      end
      it 'CREATED_NEW_OBJECT result' do
        result_code = result.first.keys.first
        expect(result_code).to eq PreservedObjectHandler::CREATED_NEW_OBJECT
        result_msg = result.first.values.first
        expect(result_msg).to match(Regexp.escape(exp_msg))
      end
    end
  end

  describe '#update' do
    let!(:default_prez_policy) { PreservationPolicy.default_preservation_policy }
  
    context 'logs errors and returns INVALID_ARGUMENTS if ActiveModel::Validations fail' do
      let(:bad_druid) { '666' }
      let(:bad_version) { 'vv666' }
      let(:bad_size) { '-666' }
      let(:bad_storage_dir) { '' }

      context 'returns' do
        let!(:result) do
          po_handler = described_class.new(bad_druid, bad_version, bad_size, bad_storage_dir)
          po_handler.update
        end
        it '1 result' do
          expect(result).to be_an_instance_of Array
          expect(result.size).to eq 1
        end
        it 'INVALID_ARGUMENTS' do
          expect(result).to include(a_hash_including(PreservedObjectHandler::INVALID_ARGUMENTS))
        end
        context 'result message includes' do
          let(:msg) { result.first[PreservedObjectHandler::INVALID_ARGUMENTS] }
          let(:exp_msg_prefix) { "PreservedObjectHandler(#{bad_druid}, #{bad_version}, #{bad_size}, #{bad_storage_dir})" }

          it "prefix" do
            expect(msg).to match(Regexp.escape("#{exp_msg_prefix} encountered validation error(s): "))
          end
          it "druid error" do
            expect(msg).to match(/Druid is invalid/)
          end
          it "version error" do
            expect(msg).to match(/Incoming version is not a number/)
          end
          it "size error" do
            expect(msg).to match(/Incoming size must be greater than 0/)
          end
          it "storage dir error" do 
            expect(msg).to match(/Endpoint can't be blank/)
          end
        end
      end
      it 'bad druid error is written to Rails log' do
        po_handler = described_class.new(bad_druid, incoming_version, incoming_size, storage_dir)
        err_msg = "PreservedObjectHandler(#{bad_druid}, #{incoming_version}, #{incoming_size}, #{storage_dir}) encountered validation error(s): [\"Druid is invalid\"]"
        allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
        po_handler.update
        expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
      end
      it 'bad version error is written to Rails log' do
        po_handler = described_class.new(druid, bad_version, incoming_size, storage_dir)
        err_msg = "PreservedObjectHandler(#{druid}, #{bad_version}, #{incoming_size}, #{storage_dir}) encountered validation error(s): [\"Incoming version is not a number\"]"
        allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
        po_handler.update
        expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
      end
      it 'bad size error is written to Rails log' do
        po_handler = described_class.new(druid, incoming_version, bad_size, storage_dir)
        err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{bad_size}, #{storage_dir}) encountered validation error(s): [\"Incoming size must be greater than 0\"]"
        allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
        po_handler.update
        expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
      end
      it 'bad storage directory is written to Rails log' do
        po_handler = described_class.new(druid, incoming_version, incoming_size, bad_storage_dir)
        err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{bad_storage_dir}) encountered validation error(s): [\"Endpoint can't be blank\"]"
        allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
        po_handler.update
        expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
      end
    end
    context 'druid in db' do
      before do
        # po = PreservedObject.find_by(druid: druid)
        # po.destroy if po
        po = PreservedObject.create!(druid: druid, current_version: 2, size: 1, preservation_policy: default_prez_policy)
        PreservationCopy.create!(
          preserved_object: po, # TODO see if we got the preserved object that we expected
          current_version: po.current_version,
          last_audited: nil,
          endpoint: Endpoint.find_by(storage_location: storage_dir),
          status: Status.find_by(status_text: "ok"), # TODO find status default message
          last_checked_on_storage: nil) # TODO nill for now, figure out how to use Time.now / ask devs
      end
      # after do
      #   po = PreservedObject.find_by(druid: druid)
      #   po.destroy if po
      # end
      let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, storage_dir) }
      let(:po) { PreservedObject.find_by(druid: druid) }
      let(:ep) { Endpoint.find_by(storage_location: storage_dir) }
      let(:pc) { PreservationCopy.find_by(preserved_object: po, endpoint: ep) }

      context "incoming and db versions match" do
        let(:po_handler) { described_class.new(druid, 2, 1, storage_dir) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 2, 1, #{storage_dir})" }
        let(:version_matches_po_msg) { "#{exp_msg_prefix} incoming version (2) matches preserved object db version" }
        let(:version_matches_pc_msg) { "#{exp_msg_prefix} incoming version (2) matches preservation copy db version" }
        let(:updated_db_timestamp_msg) { "#{exp_msg_prefix} updated db timestamp only" }

        it "entry version stays the same" do
          expect(po.current_version).to eq 2
          expect(pc.current_version).to eq 2
          po_handler.update
          expect(po.reload.current_version).to eq 2
          expect(pc.reload.current_version).to eq 2
        end
        it "entry size stays the same" do
          expect(po.size).to eq 1
          po_handler.update
          expect(po.reload.size).to eq 1
        end
        it "logs at info level" do
          allow(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_po_msg)
          allow(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_pc_msg)
          allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_db_timestamp_msg)
          po_handler.update
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, version_matches_po_msg)
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, version_matches_pc_msg)
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, updated_db_timestamp_msg).exactly(:twice)
        end
        context 'returns' do
          let!(:results) { po_handler.update }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '4 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 4
          end
          it 'PO_VERSION_MATCHES result' do
            result_msg = results.select { |r| r[PreservedObjectHandler::PO_VERSION_MATCHES] }.first.values.first
            expect(result_msg).to match(Regexp.escape(version_matches_po_msg))
          end
          it 'PC_VERSION_MATCHES result' do
            result_msg = results.select { |r| r[PreservedObjectHandler::PC_VERSION_MATCHES] }.first.values.first
            expect(result_msg).to match(Regexp.escape(version_matches_pc_msg))
          end
          it "UPDATED_DB_OBJECT_TIMESTAMP_ONLY result" do
            result_msg = results.select { |r| r[PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY] }.first.values.first
            expect(result_msg).to match(Regexp.escape(updated_db_timestamp_msg))
          end
        end
      end
      context 'incoming version newer than db version' do
        let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, storage_dir) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{storage_dir})" }
        let(:version_gt_po_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than preserved object db version" }
        let(:version_gt_pc_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than preservation copy db version" }

        let(:updated_db_msg) { "#{exp_msg_prefix} db object updated" }

        it "updates entry with incoming version" do
          expect(po.current_version).to eq 2
          expect(pc.current_version).to eq 2
          po_handler.update
          expect(po.reload.current_version).to eq incoming_version
          expect(pc.reload.current_version).to eq incoming_version
        end
        it 'updates entry with size if included' do
          expect(po.size).to eq 1
          po_handler.update
          expect(po.reload.size).to eq incoming_size
        end
        it 'retains old size if incoming size is nil' do
          expect(po.size).to eq 1
          po_handler = described_class.new(druid, incoming_version, nil, storage_dir)
          po_handler.update
          expect(po.reload.size).to eq 1
        end
        it "logs at info level" do
          allow(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_po_msg)
          allow(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_pc_msg)
          allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_db_msg)
          po_handler.update
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, version_gt_po_msg)
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, version_gt_pc_msg)
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, updated_db_msg).exactly(:twice)
        end
        context 'returns' do
          let!(:results) { po_handler.update }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '4 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 4
          end
          it 'ARG_VERSION_GREATER_THAN_PO_DB_OBJECT result' do
            result_msg = results.select { |r| r[PreservedObjectHandler::ARG_VERSION_GREATER_THAN_PO_DB_OBJECT] }.first.values.first
            expect(result_msg).to match(Regexp.escape(version_gt_po_msg))
          end
          it 'ARG_VERSION_GREATER_THAN_PC_DB_OBJECT result' do
            result_msg = results.select { |r| r[PreservedObjectHandler::ARG_VERSION_GREATER_THAN_PC_DB_OBJECT] }.first.values.first
            expect(result_msg).to match(Regexp.escape(version_gt_pc_msg))
          end
          it "UPDATED_DB_OBJECT result" do
            result_msg = results.select { |r| r[PreservedObjectHandler::UPDATED_DB_OBJECT] }.first.values.first
            expect(result_msg).to match(Regexp.escape(updated_db_msg))
          end
        end
      end

      context 'incoming version older than db version' do
        let(:po_handler) { described_class.new(druid, 1, 666, storage_dir) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 1, 666, #{storage_dir})" }
        let(:version_less_than_po_msg) { "#{exp_msg_prefix} incoming version (1) less than preserved object db version; ERROR!" }
        let(:version_less_than_pc_msg) { "#{exp_msg_prefix} incoming version (1) less than preservation copy db version; ERROR!" }
        let(:updated_db_timestamp_msg) { "#{exp_msg_prefix} updated db timestamp only" }

        it "entry version stays the same" do
          expect(po.current_version).to eq 2
          expect(pc.current_version).to eq 2
          po_handler.update
          expect(po.reload.current_version).to eq 2
          expect(pc.reload.current_version).to eq 2
        end
        it "entry size stays the same" do
          expect(po.size).to eq 1
          po_handler.update
          expect(po.reload.size).to eq 1
        end
        it "logs at error level" do
          allow(Rails.logger).to receive(:log).with(Logger::ERROR, version_less_than_po_msg)
          allow(Rails.logger).to receive(:log).with(Logger::ERROR, version_less_than_pc_msg)
          allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_db_timestamp_msg)
          po_handler.update
          expect(Rails.logger).to have_received(:log).with(Logger::ERROR, version_less_than_po_msg)
          expect(Rails.logger).to have_received(:log).with(Logger::ERROR, version_less_than_pc_msg)
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, updated_db_timestamp_msg).exactly(:twice)
        end
        context 'returns' do
          let!(:results) { po_handler.update }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '4 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 4
          end
          it 'ARG_VERSION_LESS_THAN_PO_DB_OBJECT result' do
            result_msg = results.select { |r| r[PreservedObjectHandler::ARG_VERSION_LESS_THAN_PO_DB_OBJECT] }.first.values.first
            expect(result_msg).to match(Regexp.escape(version_less_than_po_msg))
          end
          it 'ARG_VERSION_LESS_THAN_PC_DB_OBJECT result' do
            result_msg = results.select { |r| r[PreservedObjectHandler::ARG_VERSION_LESS_THAN_PC_DB_OBJECT] }.first.values.first
            expect(result_msg).to match(Regexp.escape(version_less_than_pc_msg))
          end
          # FIXME: do we want to update timestamp if we found an error (ARG_VERSION_LESS_THAN_DB_OBJECT)
          it "UPDATED_DB_OBJECT_TIMESTAMP_ONLY result" do
            result_msg = results.select { |r| r[PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY] }.first.values.first
            expect(result_msg).to match(Regexp.escape(updated_db_timestamp_msg))
          end
        end
      end
      context 'db update error' do
        context 'ActiveRecordError' do
          let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{storage_dir})" }
          let(:db_update_failed_prefix) { "#{exp_msg_prefix} db update failed" }
          let(:results) do
            allow(Rails.logger).to receive(:log)
            # FIXME: couldn't figure out how to put next line into its own test
            expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{Regexp.escape(db_update_failed_prefix)}/)

            po = instance_double("PreservedObject")
            allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
            allow(po).to receive(:current_version).and_return(1)
            allow(po).to receive(:current_version=).with(incoming_version)
            allow(po).to receive(:size=).with(incoming_size)
            allow(po).to receive(:changed?).and_return(true)
            allow(po).to receive(:save).and_raise(ActiveRecord::ActiveRecordError, 'foo')
            allow(po).to receive(:destroy) # for after() cleanup calls
            po_handler.update
          end

          it 'DB_UPDATED_FAILED error' do
            expect(results).to include(a_hash_including(PreservedObjectHandler::DB_UPDATE_FAILED))
          end
          context 'error message' do
            let(:result_msg) { results.select { |r| r[PreservedObjectHandler::DB_UPDATE_FAILED] }.first.values.first }

            it 'prefix' do
              expect(result_msg).to match(Regexp.escape(db_update_failed_prefix))
            end
            it 'specific exception raised' do
              expect(result_msg).to match(Regexp.escape('ActiveRecord::ActiveRecordError'))
            end
            it "exception's message" do
              expect(result_msg).to match(Regexp.escape('foo'))
            end
          end
        end
      end
      it 'calls PreservedObject.save and PreservationCopy.save if the existing record is altered' do
        po = instance_double(PreservedObject)
        pc = instance_double(PreservationCopy)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:current_version=).with(incoming_version)
        allow(po).to receive(:size=).with(incoming_size)
        allow(po).to receive(:changed?).and_return(true)
        allow(po).to receive(:save)
        allow(PreservationCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:current_version).and_return(1)
        allow(pc).to receive(:current_version=).with(incoming_version)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:save)
        po_handler.update
        expect(po).to have_received(:save)
        expect(pc).to have_received(:save)
      end
      it 'calls PreservedObject.touch and PreservationCopy.touch if the existing record is NOT altered' do
        po_handler = described_class.new(druid, 1, 1, storage_dir)
        po = instance_double(PreservedObject)
        pc = instance_double(PreservationCopy)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:changed?).and_return(false)
        allow(po).to receive(:touch)
        allow(PreservationCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:current_version).and_return(1)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:changed?).and_return(false)
        allow(pc).to receive(:touch)
        po_handler.update
        expect(po).to have_received(:touch)
        expect(pc).to have_received(:touch)
      end
      it 'logs a debug message' do
        msg = "update #{druid} called and object exists"
        allow(Rails.logger).to receive(:debug)
        po_handler.update
        expect(Rails.logger).to have_received(:debug).with(msg)
      end
    end
  end
end
