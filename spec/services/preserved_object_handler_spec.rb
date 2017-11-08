require 'rails_helper'

RSpec.describe PreservedObjectHandler do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' } # we are just going to assume the first rails storage root
  let!(:default_prez_policy) { PreservationPolicy.default_preservation_policy }
  let(:po) { PreservedObject.find_by(druid: druid) }
  let(:ep) { Endpoint.find_by(storage_location: storage_dir) }
  let(:pc) { PreservedCopy.find_by(preserved_object: po, endpoint: ep) }
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{storage_dir})" }
  let(:updated_status_msg_regex) { Regexp.new(Regexp.escape("#{exp_msg_prefix} PreservedCopy status changed from")) }
  let(:db_update_failed_prefix_regex_escaped) { Regexp.escape("#{exp_msg_prefix} db update failed") }
  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, storage_dir) }

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

  RSpec.shared_examples "attributes validated" do |method_sym|
    let(:bad_druid) { '666' }
    let(:bad_version) { 'vv666' }
    let(:bad_size) { '-666' }
    let(:bad_storage_dir) { '' }
    let(:bad_druid_msg) { 'Druid is invalid' }
    let(:bad_version_msg) { 'Incoming version is not a number' }
    let(:bad_size_msg) { 'Incoming size must be greater than 0' }
    let(:bad_storage_dir_msg) { "Endpoint can't be blank" }

    context 'returns' do
      let!(:result) do
        po_handler = described_class.new(bad_druid, bad_version, bad_size, bad_storage_dir)
        po_handler.send(method_sym)
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
          expect(msg).to match(bad_druid_msg)
        end
        it "version error" do
          expect(msg).to match(bad_version_msg)
        end
        it "size error" do
          expect(msg).to match(bad_size_msg)
        end
        it "storage dir error" do
          expect(msg).to match(bad_storage_dir_msg)
        end
      end
    end

    it 'bad druid error is written to Rails log' do
      po_handler = described_class.new(bad_druid, incoming_version, incoming_size, storage_dir)
      err_msg = "PreservedObjectHandler(#{bad_druid}, #{incoming_version}, #{incoming_size}, #{storage_dir}) encountered validation error(s): [\"#{bad_druid_msg}\"]"
      expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
      po_handler.send(method_sym)
    end
    it 'bad version error is written to Rails log' do
      po_handler = described_class.new(druid, bad_version, incoming_size, storage_dir)
      err_msg = "PreservedObjectHandler(#{druid}, #{bad_version}, #{incoming_size}, #{storage_dir}) encountered validation error(s): [\"#{bad_version_msg}\"]"
      expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
      po_handler.send(method_sym)
    end
    it 'bad size error is written to Rails log' do
      po_handler = described_class.new(druid, incoming_version, bad_size, storage_dir)
      err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{bad_size}, #{storage_dir}) encountered validation error(s): [\"#{bad_size_msg}\"]"
      expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
      po_handler.send(method_sym)
    end
    it 'bad storage directory is written to Rails log' do
      po_handler = described_class.new(druid, incoming_version, incoming_size, bad_storage_dir)
      err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{bad_storage_dir}) encountered validation error(s): [\"#{bad_storage_dir_msg}\"]"
      expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
      po_handler.send(method_sym)
    end
  end

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

  RSpec.shared_examples 'druid not in catalog' do |method_sym|
    let(:druid) { 'rr111rr1111' }
    let(:exp_msg) { "#{exp_msg_prefix} #<ActiveRecord::RecordNotFound: Couldn't find PreservedObject> db object does not exist" }
    let(:results) do
      allow(Rails.logger).to receive(:log)
      # FIXME: couldn't figure out how to put next line into its own test
      expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{Regexp.escape(exp_msg)}/)
      po_handler.send(method_sym)
    end

    it 'OBJECT_DOES_NOT_EXIST error' do
      code = PreservedObjectHandler::OBJECT_DOES_NOT_EXIST
      expect(results).to include(a_hash_including(code => exp_msg))
    end
  end

  RSpec.shared_examples 'PreservedCopy does not exist' do |method_sym|
    before do
      PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
    end
    let(:exp_msg) { "#{exp_msg_prefix} #<ActiveRecord::RecordNotFound: foo> db object does not exist" }
    let(:results) do
      allow(Rails.logger).to receive(:log)
      # FIXME: couldn't figure out how to put next line into its own test
      expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{Regexp.escape(exp_msg)}/)
      po = instance_double(PreservedObject)
      allow(po).to receive(:current_version).and_return(2)
      allow(po).to receive(:current_version=)
      allow(po).to receive(:changed?).and_return(true)
      allow(po).to receive(:save!)
      allow(PreservedObject).to receive(:find_by!).and_return(po)
      # allow(PreservedObject).to receive(:find_by!).and_return(instance_double(PreservedObject))
      allow(PreservedCopy).to receive(:find_by!).and_raise(ActiveRecord::RecordNotFound, 'foo')
      po_handler.send(method_sym)
    end

    it 'OBJECT_DOES_NOT_EXIST error' do
      code = PreservedObjectHandler::OBJECT_DOES_NOT_EXIST
      expect(results).to include(a_hash_including(code => exp_msg))
    end
  end

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
          status: Status.unexpected_version
        )
      end

      context 'incoming version newer than db versions (both) (happy path)' do
        let(:version_gt_pc_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedCopy db version" }
        let(:version_gt_po_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedObject db version" }
        let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }
        let(:updated_po_db_msg) { "#{exp_msg_prefix} PreservedObject db object updated" }

        it "updates entries with incoming version" do
          expect(pc.version).to eq 2
          expect(po.current_version).to eq 2
          po_handler.update_version
          expect(pc.reload.version).to eq incoming_version
          expect(po.reload.current_version).to eq incoming_version
        end
        it 'updates entries with size if included' do
          expect(pc.size).to eq 1
          po_handler.update_version
          expect(pc.reload.size).to eq incoming_size
        end
        it 'retains old size if incoming size is nil' do
          expect(pc.size).to eq 1
          po_handler = described_class.new(druid, incoming_version, nil, storage_dir)
          po_handler.update_version
          expect(pc.reload.size).to eq 1
        end
        it 'updates status of PreservedCopy to "ok"' do
          expect(pc.status).to eq Status.unexpected_version
          po_handler.update_version
          expect(pc.reload.status).to eq Status.ok
        end
        it "logs at info level" do
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_po_db_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_status_msg_regex)
          po_handler.update_version
        end

        context 'returns' do
          let!(:results) { po_handler.update_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '5 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 5
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
          it 'PC_STATUS_CHANGED result' do
            expect(results).to include(a_hash_including(PreservedObjectHandler::PC_STATUS_CHANGED => updated_status_msg_regex))
          end
        end
      end

      RSpec.shared_examples 'unexpected version' do |incoming_version|
        let(:po_handler) { described_class.new(druid, incoming_version, 1, storage_dir) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, 1, #{storage_dir})" }
        let(:version_msg_prefix) { "#{exp_msg_prefix} incoming version (#{incoming_version})" }
        let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to PreservedCopy db version; ERROR!" }
        let(:updated_po_db_timestamp_msg) { "#{exp_msg_prefix} PreservedObject updated db timestamp only" }
        let(:updated_pc_db_timestamp_msg) { "#{exp_msg_prefix} PreservedCopy updated db timestamp only" }

        it "entry version stays the same" do
          pocv = po.current_version
          pcv = pc.version
          po_handler.update_version
          expect(po.reload.current_version).to eq pocv
          expect(pc.reload.version).to eq pcv
        end
        it "entry size stays the same" do
          expect(pc.size).to eq 1
          po_handler.update_version
          expect(pc.reload.size).to eq 1
        end
        it 'updates status of PreservedCopy to "ok"' do
          skip("should it update status of PreservedCopy?")
          expect(pc.status).to eq Status.unexpected_version
          po_handler.update_version
          expect(pc.reload.status).to eq Status.ok
        end
        it "logs at error level" do
          expect(Rails.logger).to receive(:log).with(Logger::ERROR, unexpected_version_msg)
          skip("should it have status msg change? timestamp change?")
          # expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_timestamp_msg)
          # expect(Rails.logger).to receive(:log).with(Logger::ERROR, updated_po_db_timestamp_msg)
          # expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_status_msg_regex)
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
          it "UPDATED_DB_OBJECT_TIMESTAMP_ONLY results" do
            skip("should it have a timestamp change?")
            code = PreservedObjectHandler::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_timestamp_msg))
            expect(results).to include(a_hash_including(code => updated_po_db_timestamp_msg))
          end
          it 'PC_STATUS_CHANGED result' do
            skip("should it have status msg change?")
            expect(results).to include(a_hash_including(PreservedObjectHandler::PC_STATUS_CHANGED => updated_status_msg_regex))
          end
        end
      end

      context 'PreservedCopy and PreservedObject versions do not match' do
        before do
          @pc.version = @pc.version + 1
          @pc.save
        end

        it_behaves_like 'unexpected version', 8
      end

      context 'incoming version same as db versions (both)' do
        it_behaves_like 'unexpected version', 2
      end

      context 'incoming version lower than db versions (both)' do
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
              allow(pc).to receive(:changed?).and_return(true)
              allow(pc).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              status = instance_double('Status')
              allow(status).to receive(:status_text)
              allow(pc).to receive(:status).and_return(status)
              allow(pc).to receive(:status=)
              allow(pc).to receive(:size=)
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
              allow(pc).to receive(:changed?).and_return(true)
              allow(pc).to receive(:save!)
              status = instance_double('Status')
              allow(status).to receive(:status_text)
              allow(pc).to receive(:status).and_return(status)
              allow(pc).to receive(:status=)
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
            end
          end
        end
      end

      it 'calls PreservedObject.save! and PreservedCopy.save! if the existing record is altered' do
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:current_version=).with(incoming_version)
        allow(po).to receive(:changed?).and_return(true)
        allow(po).to receive(:save!)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:version=).with(incoming_version)
        allow(pc).to receive(:size=).with(incoming_size)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:status).and_return(instance_double(Status, status_text: 'ok'))
        allow(pc).to receive(:status=)
        allow(pc).to receive(:save!)
        po_handler.update_version
        expect(po).to have_received(:save!)
        expect(pc).to have_received(:save!)
      end

      it 'calls PreservedObject.touch and PreservedCopy.touch if the existing record is NOT altered' do
        skip('need to determine if we want to update timestamps in this situation')
        po_handler = described_class.new(druid, 1, 1, storage_dir)
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:changed?).and_return(false)
        allow(po).to receive(:touch)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:changed?).and_return(false)
        allow(pc).to receive(:touch)
        po_handler.update_version
        expect(po).to have_received(:touch)
        expect(pc).to have_received(:touch)
      end

      it 'logs a debug message' do
        msg = "update_version #{druid} called and druid in Catalog"
        allow(Rails.logger).to receive(:debug)
        po_handler.update_version
        expect(Rails.logger).to have_received(:debug).with(msg)
      end
    end

    it_behaves_like 'druid not in catalog', :update_version

    it_behaves_like 'PreservedCopy does not exist', :update_version
  end

  describe '#confirm_version' do
    it_behaves_like 'attributes validated', :confirm_version

    context 'druid in db' do
      before do
        po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        PreservedCopy.create!(
          preserved_object: po, # TODO: see if we got the preserved object that we expected
          version: po.current_version,
          size: 1,
          endpoint: ep,
          status: Status.default_status
        )
      end

      context "incoming and db versions match" do
        let(:po_handler) { described_class.new(druid, 2, 1, storage_dir) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 2, 1, #{storage_dir})" }
        let(:version_matches_po_msg) { "#{exp_msg_prefix} incoming version (2) matches PreservedObject db version" }
        let(:version_matches_pc_msg) { "#{exp_msg_prefix} incoming version (2) matches PreservedCopy db version" }
        let(:updated_po_db_timestamp_msg) { "#{exp_msg_prefix} PreservedObject updated db timestamp only" }
        let(:updated_pc_db_timestamp_msg) { "#{exp_msg_prefix} PreservedCopy updated db timestamp only" }

        it "entry version stays the same" do
          expect(po.current_version).to eq 2
          expect(pc.version).to eq 2
          po_handler.confirm_version
          expect(po.reload.current_version).to eq 2
          expect(pc.reload.version).to eq 2
        end
        it "entry size stays the same" do
          expect(pc.size).to eq 1
          po_handler.confirm_version
          expect(pc.reload.size).to eq 1
        end
        it "logs at info level" do
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_po_db_timestamp_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_timestamp_msg)
          po_handler.confirm_version
        end
        context 'returns' do
          let!(:results) { po_handler.confirm_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '4 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 4
          end
          it 'VERSION_MATCHES results' do
            code = PreservedObjectHandler::VERSION_MATCHES
            expect(results).to include(a_hash_including(code => version_matches_pc_msg))
            expect(results).to include(a_hash_including(code => version_matches_po_msg))
          end
          it 'UPDATED_DB_OBJECT_TIMESTAMP_ONLY results' do
            code = PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY
            expect(results).to include(a_hash_including(code => updated_pc_db_timestamp_msg))
            expect(results).to include(a_hash_including(code => updated_po_db_timestamp_msg))
          end
        end
      end
      context 'incoming version newer than db version' do
        let(:version_gt_po_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedObject db version" }
        let(:version_gt_pc_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedCopy db version" }

        let(:updated_po_db_msg) { "#{exp_msg_prefix} PreservedObject db object updated" }
        let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }

        it "updates entry with incoming version" do
          expect(po.current_version).to eq 2
          expect(pc.version).to eq 2
          po_handler.confirm_version
          expect(po.reload.current_version).to eq incoming_version
          expect(pc.reload.version).to eq incoming_version
        end
        it 'updates entry with size if included' do
          expect(pc.size).to eq 1
          po_handler.confirm_version
          expect(pc.reload.size).to eq incoming_size
        end
        it 'retains old size if incoming size is nil' do
          expect(pc.size).to eq 1
          po_handler = described_class.new(druid, incoming_version, nil, storage_dir)
          po_handler.confirm_version
          expect(pc.reload.size).to eq 1
        end
        it "logs at info level" do
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_po_db_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
          po_handler.confirm_version
        end
        context 'returns' do
          let!(:results) { po_handler.confirm_version }

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
          it 'UPDATED_DB_OBJECT results' do
            code = PreservedObjectHandler::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_msg))
            expect(results).to include(a_hash_including(code => updated_po_db_msg))
          end
        end
      end

      context 'incoming version older than db version' do
        let(:po_handler) { described_class.new(druid, 1, 666, storage_dir) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 1, 666, #{storage_dir})" }
        let(:version_less_than_po_msg) { "#{exp_msg_prefix} incoming version (1) less than PreservedObject db version; ERROR!" }
        let(:version_less_than_pc_msg) { "#{exp_msg_prefix} incoming version (1) less than PreservedCopy db version; ERROR!" }
        let(:updated_po_db_timestamp_msg) { "#{exp_msg_prefix} PreservedObject updated db timestamp only" }
        let(:updated_pc_db_obj_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }
        let(:updated_pc_db_status_msg) do
          "#{exp_msg_prefix} PreservedCopy status changed from ok to expected_version_not_found_on_disk"
        end

        it "entry version stays the same" do
          expect(po.current_version).to eq 2
          expect(pc.version).to eq 2
          po_handler.confirm_version
          expect(po.reload.current_version).to eq 2
          expect(pc.reload.version).to eq 2
        end
        it "entry size stays the same" do
          expect(pc.size).to eq 1
          po_handler.confirm_version
          expect(pc.reload.size).to eq 1
        end
        it "logs at error level" do
          expect(Rails.logger).to receive(:log).with(Logger::ERROR, version_less_than_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::ERROR, version_less_than_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_po_db_timestamp_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_obj_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_status_msg)
          po_handler.confirm_version
        end
        context 'returns' do
          let!(:results) { po_handler.confirm_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '5 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 5
          end
          it 'ARG_VERSION_LESS_THAN_DB_OBJECT results' do
            code = PreservedObjectHandler::ARG_VERSION_LESS_THAN_DB_OBJECT
            expect(results).to include(a_hash_including(code => version_less_than_pc_msg))
            expect(results).to include(a_hash_including(code => version_less_than_po_msg))
          end
          # FIXME: do we want to update timestamp if we found an error (ARG_VERSION_LESS_THAN_DB_OBJECT)
          it "PreservedObject UPDATED_DB_OBJECT_TIMESTAMP_ONLY result" do
            code = PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY
            expect(results).to include(a_hash_including(code => updated_po_db_timestamp_msg))
          end
          it "PreservedCopy UPDATED_DB_OBJECT result" do
            code = PreservedObjectHandler::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_obj_msg))
          end
          it "PreservedCopy PC_STATUS_CHANGED result" do
            code = PreservedObjectHandler::PC_STATUS_CHANGED
            expect(results).to include(a_hash_including(code => updated_pc_db_status_msg))
          end
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
            allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
            allow(po).to receive(:current_version).and_return(1)
            allow(po).to receive(:current_version=).with(incoming_version)
            allow(po).to receive(:changed?).and_return(true)
            allow(po).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
            allow(po).to receive(:destroy) # for after() cleanup calls
            po_handler.confirm_version
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
      it 'calls PreservedObject.save! and PreservedCopy.save! if the existing record is altered' do
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)

        # bad object-oriented form!  type checking like this is to be avoided.  but also, wouldn't
        # it be nice if an rspec double returned `true` when asked if it was an instance or kind of
        # the object type being mocked?  i think that'd be nice.  but that's not what doubles do.
        allow(po).to receive(:is_a?).with(PreservedObject).and_return(true)
        allow(po).to receive(:is_a?).with(PreservedCopy).and_return(false)
        allow(pc).to receive(:is_a?).with(PreservedObject).and_return(false)
        allow(pc).to receive(:is_a?).with(PreservedCopy).and_return(true)

        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:current_version=).with(incoming_version)
        allow(po).to receive(:changed?).and_return(true)
        allow(po).to receive(:save!)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:version=).with(incoming_version)
        allow(pc).to receive(:size=).with(incoming_size)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:status).and_return(Status.ok)
        allow(pc).to receive(:save!)
        po_handler.confirm_version
        expect(po).to have_received(:save!)
        expect(pc).to have_received(:save!)
      end
      it 'calls PreservedObject.touch and PreservedCopy.touch if the existing record is NOT altered' do
        po_handler = described_class.new(druid, 1, 1, storage_dir)
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:changed?).and_return(false)
        allow(po).to receive(:touch)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:changed?).and_return(false)
        allow(pc).to receive(:touch)
        po_handler.confirm_version
        expect(po).to have_received(:touch)
        expect(pc).to have_received(:touch)
      end
      it 'logs a debug message' do
        msg = "confirm_version #{druid} called and object exists"
        allow(Rails.logger).to receive(:debug)
        po_handler.confirm_version
        expect(Rails.logger).to have_received(:debug).with(msg)
      end
    end

    it_behaves_like 'druid not in catalog', :confirm_version

    it_behaves_like 'PreservedCopy does not exist', :confirm_version
  end
end
