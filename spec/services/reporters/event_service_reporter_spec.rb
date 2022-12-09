# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reporters::EventServiceReporter do
  let(:subject) { described_class.new }

  let(:druid) { 'ab123cd4567' }
  let(:actual_version) { 6 }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:check_name) { 'FooCheck' }

  before do
    allow(Socket).to receive(:gethostname).and_return('fakehost')
    allow(Dor::Event::Client).to receive(:create)
  end

  describe '#report_errors' do
    context 'when INVALID_MOAB' do
      let(:result1) do
        { AuditResults::INVALID_MOAB => 'Invalid Moab, validation errors: [Version directory name not in ' \
                                        "'v00xx' format: original-v1]" }
      end
      let(:result2) do
        { AuditResults::INVALID_MOAB => 'Invalid Moab, validation errors: [Version directory name not in ' \
                                        "'v00xx' format: original-v2]" }
      end

      it 'creates events' do
        subject.report_errors(druid: druid, version: actual_version, storage_area: ms_root, check_name: check_name, results: [result1, result2])
        error1 = 'FooCheck (actual location: fixture_sr1; actual version: 6) || Invalid Moab, validation errors: ' \
                 "[Version directory name not in 'v00xx' format: original-v1]"
        expect(Dor::Event::Client).to have_received(:create).with(
          druid: "druid:#{druid}",
          type: 'preservation_audit_failure',
          data: {
            host: 'fakehost',
            invoked_by: 'preservation-catalog',
            storage_area: 'fixture_sr1',
            actual_version: 6,
            check_name: 'moab-valid',
            error: error1
          }
        )
        error2 = 'FooCheck (actual location: fixture_sr1; actual version: 6) || Invalid Moab, validation errors: ' \
                 "[Version directory name not in 'v00xx' format: original-v2]"
        expect(Dor::Event::Client).to have_received(:create).with(
          druid: "druid:#{druid}",
          type: 'preservation_audit_failure',
          data: {
            host: 'fakehost',
            invoked_by: 'preservation-catalog',
            storage_area: 'fixture_sr1',
            actual_version: 6,
            check_name: 'moab-valid',
            error: error2
          }
        )
      end
    end

    context 'when other errors' do
      let(:result1) { { AuditResults::DB_VERSIONS_DISAGREE => 'does not match PreservedObject current_version' } }
      let(:result2) { { AuditResults::UNEXPECTED_VERSION => 'actual version (6) has unexpected relationship to db version' } }

      it 'merges errors and creates single event' do
        subject.report_errors(druid: druid, version: actual_version, storage_area: ms_root, check_name: check_name, results: [result1, result2])
        expect(Dor::Event::Client).to have_received(:create).with(
          druid: "druid:#{druid}",
          type: 'preservation_audit_failure',
          data: {
            host: 'fakehost',
            invoked_by: 'preservation-catalog',
            storage_area: 'fixture_sr1',
            actual_version: 6,
            check_name: 'preservation-audit',
            error: 'FooCheck (actual location: fixture_sr1; actual version: 6) does not match PreservedObject ' \
                   'current_version && actual version (6) has unexpected relationship to db version'
          }
        )
      end
    end
  end

  describe '#report_completed' do
    let(:result) { { AuditResults::MOAB_RECORD_STATUS_CHANGED => 'MoabRecord status changed from invalid_moab' } }

    it 'creates events' do
      subject.report_completed(druid: druid, version: actual_version, storage_area: ms_root, check_name: check_name, result: result)

      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'preservation_audit_success',
        data: {
          host: 'fakehost',
          invoked_by: 'preservation-catalog',
          storage_area: 'fixture_sr1',
          actual_version: 6,
          check_name: 'preservation-audit'
        }
      )

      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'preservation_audit_success',
        data: {
          host: 'fakehost',
          invoked_by: 'preservation-catalog',
          storage_area: 'fixture_sr1',
          actual_version: 6,
          check_name: 'moab-valid'
        }
      )
    end
  end
end
