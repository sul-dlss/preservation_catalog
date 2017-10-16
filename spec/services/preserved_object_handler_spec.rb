require 'rails_helper'

RSpec.describe PreservedObjectHandler do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }

  describe '#initialize' do
    it 'sets druid' do
      po_handler = described_class.new(druid, incoming_version, nil)
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
          po_handler = described_class.new(druid, k, nil)
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
          po_handler = described_class.new(druid, nil, k)
          expect(po_handler.incoming_size).to eq v
        end
      end
    end
  end

  describe '#update_or_create' do
    let!(:default_prez_policy) { PreservationPolicy.find_by(preservation_policy_name: 'default') }

    context 'logs errors and returns INVALID_ARGUMENTS if ActiveModel::Validations fail' do
      let(:bad_druid) { '666' }
      let(:bad_version) { 'vv666' }
      let(:bad_size) { '-666' }

      context 'returns' do
        let!(:result) do
          po_handler = described_class.new(bad_druid, bad_version, bad_size)
          po_handler.update_or_create
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
          let(:exp_msg_prefix) { "PreservedObjectHandler(#{bad_druid}, #{bad_version}, #{bad_size})" }

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
        end
      end
      it 'bad druid error is written to Rails log' do
        po_handler = described_class.new(bad_druid, incoming_version, incoming_size)
        err_msg = "PreservedObjectHandler(#{bad_druid}, #{incoming_version}, #{incoming_size}) encountered validation error(s): [\"Druid is invalid\"]"
        allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
        po_handler.update_or_create
        expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
      end
      it 'bad version error is written to Rails log' do
        po_handler = described_class.new(druid, bad_version, incoming_size)
        err_msg = "PreservedObjectHandler(#{druid}, #{bad_version}, #{incoming_size}) encountered validation error(s): [\"Incoming version is not a number\"]"
        allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
        po_handler.update_or_create
        expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
      end
      it 'bad size error is written to Rails log' do
        po_handler = described_class.new(druid, incoming_version, bad_size)
        err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{bad_size}) encountered validation error(s): [\"Incoming size must be greater than 0\"]"
        allow(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
        po_handler.update_or_create
        expect(Rails.logger).to have_received(:log).with(Logger::ERROR, err_msg)
      end
    end

    context 'druid in db' do
      before do
        po = PreservedObject.find_by(druid: druid)
        po.destroy if po
        PreservedObject.create!(druid: druid, current_version: 2, size: 1, preservation_policy: default_prez_policy)
      end
      after do
        po = PreservedObject.find_by(druid: druid)
        po.destroy if po
      end
      let(:po_handler) { described_class.new(druid, incoming_version, incoming_size) }
      let(:po) { PreservedObject.find_by(druid: druid) }

      context "incoming and db versions match" do
        let(:po_handler) { described_class.new(druid, 2, 1) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 2, 1)" }
        let(:version_matches_msg) { "#{exp_msg_prefix} incoming version (2) matches db version" }
        let(:updated_db_timestamp_msg) { "#{exp_msg_prefix} updated db timestamp only" }

        it "entry version stays the same" do
          expect(po.current_version).to eq 2
          po_handler.update_or_create
          expect(po.reload.current_version).to eq 2
        end
        it "entry size stays the same" do
          expect(po.size).to eq 1
          po_handler.update_or_create
          expect(po.reload.size).to eq 1
        end
        it "logs at info level" do
          allow(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_msg)
          allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_db_timestamp_msg)
          po_handler.update_or_create
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, version_matches_msg)
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, updated_db_timestamp_msg)
        end
        context 'returns' do
          let!(:results) { po_handler.update_or_create }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '2 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 2
          end
          it 'VERSION_MATCHES result' do
            result_msg = results.select { |r| r[PreservedObjectHandler::VERSION_MATCHES] }.first.values.first
            expect(result_msg).to match(Regexp.escape(version_matches_msg))
          end
          it "UPDATED_DB_OBJECT_TIMESTAMP_ONLY result" do
            result_msg = results.select { |r| r[PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY] }.first.values.first
            expect(result_msg).to match(Regexp.escape(updated_db_timestamp_msg))
          end
        end
      end

      context 'incoming version newer than db version' do
        let(:po_handler) { described_class.new(druid, incoming_version, incoming_size) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size})" }
        let(:version_gt_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than db version" }
        let(:updated_db_msg) { "#{exp_msg_prefix} db object updated" }

        it "updates entry with incoming version" do
          expect(po.current_version).to eq 2
          po_handler.update_or_create
          expect(po.reload.current_version).to eq incoming_version
        end
        it 'updates entry with size if included' do
          expect(po.size).to eq 1
          po_handler.update_or_create
          expect(po.reload.size).to eq incoming_size
        end
        it 'retains old size if incoming size is nil' do
          expect(po.size).to eq 1
          po_handler = described_class.new(druid, incoming_version, nil)
          po_handler.update_or_create
          expect(po.reload.size).to eq 1
        end
        it "logs at info level" do
          allow(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_msg)
          allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_db_msg)
          po_handler.update_or_create
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, version_gt_msg)
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, updated_db_msg)
        end
        context 'returns' do
          let!(:results) { po_handler.update_or_create }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '2 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 2
          end
          it 'ARG_VERSION_GREATER_THAN_DB_OBJECT result' do
            result_msg = results.select { |r| r[PreservedObjectHandler::ARG_VERSION_GREATER_THAN_DB_OBJECT] }.first.values.first
            expect(result_msg).to match(Regexp.escape(version_gt_msg))
          end
          it "UPDATED_DB_OBJECT result" do
            result_msg = results.select { |r| r[PreservedObjectHandler::UPDATED_DB_OBJECT] }.first.values.first
            expect(result_msg).to match(Regexp.escape(updated_db_msg))
          end
        end
      end

      context 'incoming version older than db version' do
        let(:po_handler) { described_class.new(druid, 1, 666) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 1, 666)" }
        let(:version_less_than_msg) { "#{exp_msg_prefix} incoming version (1) less than db version; ERROR!" }
        let(:updated_db_timestamp_msg) { "#{exp_msg_prefix} updated db timestamp only" }

        it "entry version stays the same" do
          expect(po.current_version).to eq 2
          po_handler.update_or_create
          expect(po.reload.current_version).to eq 2
        end
        it "entry size stays the same" do
          expect(po.size).to eq 1
          po_handler.update_or_create
          expect(po.reload.size).to eq 1
        end
        it "logs at error level" do
          allow(Rails.logger).to receive(:log).with(Logger::ERROR, version_less_than_msg)
          allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_db_timestamp_msg)
          po_handler.update_or_create
          expect(Rails.logger).to have_received(:log).with(Logger::ERROR, version_less_than_msg)
          expect(Rails.logger).to have_received(:log).with(Logger::INFO, updated_db_timestamp_msg)
        end
        context 'returns' do
          let!(:results) { po_handler.update_or_create }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '2 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 2
          end
          it 'ARG_VERSION_LESS_THAN_DB_OBJECT result' do
            result_msg = results.select { |r| r[PreservedObjectHandler::ARG_VERSION_LESS_THAN_DB_OBJECT] }.first.values.first
            expect(result_msg).to match(Regexp.escape(version_less_than_msg))
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
          let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size})" }
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
            po_handler.update_or_create
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

      it 'calls PreservedObject.save if the existing record is altered' do
        po = instance_double(PreservedObject)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:current_version=).with(incoming_version)
        allow(po).to receive(:size=).with(incoming_size)
        allow(po).to receive(:changed?).and_return(true)
        allow(po).to receive(:save)
        po_handler.update_or_create
        expect(po).to have_received(:save)

        allow(po).to receive(:destroy)
      end
      it 'calls PreservedObject.touch if the existing record is NOT altered' do
        po_handler = described_class.new(druid, 1, 1)
        po = instance_double(PreservedObject)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:changed?).and_return(false)
        allow(po).to receive(:touch)
        po_handler.update_or_create
        expect(po).to have_received(:touch)

        allow(po).to receive(:destroy)
      end
      it 'logs a debug message' do
        msg = "update #{druid} called and object exists"
        allow(Rails.logger).to receive(:debug)
        po_handler.update_or_create
        expect(Rails.logger).to have_received(:debug).with(msg)
      end
    end

    context 'druid not in db (yet)' do
      after do
        po = PreservedObject.find_by(druid: druid)
        po.destroy if po
      end
      let(:po_handler) { described_class.new(druid, incoming_version, incoming_size) }
      let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size})" }
      let(:exp_msg) { "#{exp_msg_prefix} added object to db as it did not exist" }

      it 'creates the object' do
        args = {
          druid: druid,
          current_version: incoming_version,
          size: incoming_size,
          preservation_policy: an_instance_of(PreservationPolicy)
        }
        allow(PreservedObject).to receive(:create).with(args)
        po_handler.update_or_create
        expect(PreservedObject).to have_received(:create).with(args)
      end
      it 'logs a warning' do
        allow(Rails.logger).to receive(:log).with(Logger::WARN, exp_msg)
        po_handler.update_or_create
        expect(Rails.logger).to have_received(:log).with(Logger::WARN, exp_msg)
      end
      context 'returns' do
        let!(:result) { po_handler.update_or_create }

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
  end
end
