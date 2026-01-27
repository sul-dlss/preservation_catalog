# frozen_string_literal: true

require 'rails_helper'
require 'services/moab_service/shared_examples'

RSpec.describe MoabService::UpdateVersion do
  let(:db_update_failed_prefix) { 'db update failed' }
  let(:druid) { 'ab123cd4567' }
  let(:incoming_size) { 9876 }
  let(:incoming_version) { 6 }
  let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:preserved_object) { PreservedObject.find_by(druid: druid) }
  let(:moab_record) { moab_record_service.moab_record }
  let(:moab_record_service) do
    described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: moab_storage_root)
  end
  let(:logger_reporter) { instance_double(ResultsReporters::LoggerReporter, report_errors: nil, report_completed: nil) }
  let(:honeybadger_reporter) { instance_double(ResultsReporters::HoneybadgerReporter, report_errors: nil, report_completed: nil) }
  let(:event_service_reporter) { instance_double(ResultsReporters::EventServiceReporter, report_errors: nil, report_completed: nil) }

  before do
    allow(ResultsReporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(ResultsReporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(ResultsReporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
    allow(ReplicationJob).to receive(:perform_later)
  end

  describe '#execute' do
    it_behaves_like 'attributes validated'

    context 'in Catalog' do
      before do
        create(:preserved_object, druid: druid, current_version: 2)
        preserved_object.create_moab_record!(
          version: preserved_object.current_version,
          size: 1,
          moab_storage_root: moab_storage_root,
          status: 'ok', # pretending we checked for moab validation errs at create time
          last_version_audit: Time.current,
          last_moab_validation: Time.current
        )
      end

      context 'incoming version newer than catalog versions (both) (happy path)' do
        context 'MoabRecord' do
          context 'changed' do
            it 'version becomes incoming_version' do
              expect { moab_record_service.execute }.to change(moab_record, :version).to be(incoming_version)
            end

            it 'last_version_audit' do
              expect { moab_record_service.execute }.to change(moab_record, :last_version_audit)
            end

            it 'size if supplied' do
              expect { moab_record_service.execute }.to change(moab_record, :size)
            end
          end

          context 'unchanged' do
            it 'size if incoming size is nil' do
              moab_record_service = described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: nil,
                                                        moab_storage_root: moab_storage_root)
              expect { moab_record_service.execute }.not_to change { moab_record_service.moab_record.size }
            end

            it 'last_moab_validation' do
              expect { moab_record_service.execute }.not_to change(moab_record, :last_moab_validation)
            end
          end

          context 'status' do
            context 'checksums_validated = false' do
              it 'starting status validity_unknown unchanged' do
                moab_record.update!(status: 'validity_unknown')
                expect { moab_record_service.execute }.not_to change(moab_record, :status).from('validity_unknown')
              end

              context 'starting status not validity_unknown' do
                shared_examples '#update_version changes status to "validity_unknown"' do |orig_status|
                  before { moab_record.update!(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect { moab_record_service.execute }.to change(moab_record, :status)
                      .from(orig_status).to('validity_unknown')
                  end
                end

                it_behaves_like '#update_version changes status to "validity_unknown"', 'ok'
                it_behaves_like '#update_version changes status to "validity_unknown"', 'invalid_moab'
                it_behaves_like '#update_version changes status to "validity_unknown"', 'invalid_checksum'
                it_behaves_like '#update_version changes status to "validity_unknown"', 'moab_on_storage_not_found'
                it_behaves_like '#update_version changes status to "validity_unknown"', 'unexpected_version_on_storage'
              end
            end

            context 'checksums_validated = true' do
              it 'starting status ok unchanged' do
                expect { moab_record_service.execute(checksums_validated: true) }.not_to change(moab_record, :status).from('ok')
              end

              context 'original status was not ok' do
                shared_examples '#update_version(true) does not change status' do |orig_status|
                  before { moab_record.update!(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect { moab_record_service.execute(checksums_validated: true) }.not_to change(moab_record, :status)
                  end
                end

                it_behaves_like '#update_version(true) does not change status', 'validity_unknown'
                it_behaves_like '#update_version(true) does not change status', 'invalid_moab'
                it_behaves_like '#update_version(true) does not change status', 'invalid_checksum'
                # TODO: do these statuses change?
                it_behaves_like '#update_version(true) does not change status', 'moab_on_storage_not_found'
                it_behaves_like '#update_version(true) does not change status', 'unexpected_version_on_storage'
              end
            end
          end
        end

        context 'calls #update_catalog with' do
          it 'status = "validity_unknown" for checksums_validated = false' do
            expect(moab_record_service).to receive(:update_catalog).with(status: 'validity_unknown', set_status_to_unexpected_version: true,
                                                                         checksums_validated: false).and_call_original
            moab_record_service.execute
            skip 'test is weak b/c we only indirectly show the effects of #update_catalog in #update_version specs'
          end

          it 'status = "ok" and checksums_validated = true for checksums_validated = true' do
            expect(moab_record_service).to receive(:update_catalog).with(status: nil, set_status_to_unexpected_version: true,
                                                                         checksums_validated: true).and_call_original
            moab_record_service.execute(checksums_validated: true)
            skip 'test is weak b/c we only indirectly show the effects of #update_catalog in #update_version specs'
          end
        end

        context 'PreservedObject changed' do
          it 'current_version becomes incoming version' do
            expect { moab_record_service.execute }.to change(moab_record_service.preserved_object, :current_version)
              .to(incoming_version)
            expect(ReplicationJob).to have_received(:perform_later).with(preserved_object)
          end
        end

        it_behaves_like 'calls ResultsReporter.report_results'

        context 'returns' do
          let!(:results) { moab_record_service.execute(checksums_validated: true) }

          it '1 results' do
            expect(results).to be_an_instance_of Results
            expect(results.size).to eq 1
          end

          it 'ACTUAL_VERS_GT_DB_OBJ results' do
            code = Results::ACTUAL_VERS_GT_DB_OBJ
            version_greater_than_moab_record_msg = "actual version (#{incoming_version}) greater than MoabRecord db version (2)"
            expect(results.to_a).to include(a_hash_including(code => version_greater_than_moab_record_msg))
          end
        end
      end

      context 'MoabRecord and PreservedObject versions do not match' do
        before { moab_record.update(version: moab_record.version + 1) }

        it_behaves_like 'PreservedObject current_version does not match MoabRecord version', 3, 3, 2
      end

      context 'incoming version same as catalog versions (both)' do
        it_behaves_like 'unexpected version', 2, 'ok'
      end

      context 'incoming version lower than catalog versions (both)' do
        it_behaves_like 'unexpected version', 1
      end

      context 'db update error' do
        let(:result_code) { Results::DB_UPDATE_FAILED }

        context 'MoabRecord' do
          context 'ActiveRecordError' do
            let(:results) do
              allow(Rails.logger).to receive(:log)
              allow(moab_record_service).to receive_messages(preserved_object: preserved_object, moab_record: moab_record)
              allow(moab_record).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              moab_record_service.execute
            end

            context 'DB_UPDATE_FAILED error' do
              it 'prefix' do
                expect(results.to_a).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
              end

              it 'specific exception raised' do
                expect(results.to_a).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
              end

              it "exception's message" do
                expect(results.to_a).to include(a_hash_including(result_code => a_string_matching('foo')))
              end
            end
          end
        end

        context 'PreservedObject' do
          context 'ActiveRecordError' do
            let(:druid) { 'zy666xw4567' }
            let(:results) do
              allow(Rails.logger).to receive(:log)
              allow(moab_record_service).to receive(:preserved_object).and_return(preserved_object)
              allow(preserved_object).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              moab_record_service.execute
            end

            context 'DB_UPDATE_FAILED error' do
              it 'prefix' do
                expect(results.to_a).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
              end

              it 'specific exception raised' do
                expect(results.to_a).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
              end

              it "exception's message" do
                expect(results.to_a).to include(a_hash_including(result_code => a_string_matching('foo')))
              end
            end
          end
        end
      end

      it 'calls PreservedObject.save! and MoabRecord.save! if the records are altered' do
        allow(moab_record_service).to receive(:preserved_object).and_return(preserved_object)
        allow(moab_record_service.preserved_object).to receive(:moab_record).and_return(moab_record)
        expect(preserved_object).to receive(:save!)
        expect(moab_record).to receive(:save!)
        moab_record_service.execute
      end

      context '' do
        let(:moab_record_service) { described_class.new(druid: druid, incoming_version: 1, incoming_size: 1, moab_storage_root: moab_storage_root) }

        it 'does not call PreservedObject.save when MoabRecord only has timestamp updates' do
          allow(moab_record_service).to receive(:preserved_object).and_return(preserved_object)
          allow(moab_record_service.preserved_object).to receive(:moab_record).and_return(moab_record)
          expect(moab_record).to receive(:save!)
          expect(preserved_object).not_to receive(:save!)
          moab_record_service.execute
        end
      end

      it 'logs a debug message' do
        allow(Rails.logger).to receive(:debug)
        moab_record_service.execute
        expect(Rails.logger).to have_received(:debug).with("update_version #{druid} called")
      end
    end

    it_behaves_like 'druid not in catalog'

    context 'only PreservedObject exists' do
      before { create(:preserved_object, druid: druid, moab_record: nil) }

      it_behaves_like 'MoabRecord does not exist'
    end
  end
end
