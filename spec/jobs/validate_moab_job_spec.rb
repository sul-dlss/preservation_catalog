# frozen_string_literal: true

require 'rails_helper'

describe ValidateMoabJob, type: :job do
  let(:job) { described_class.new }
  let(:bare_druid) { 'bj102hs9687' }
  let(:druid) { "druid:#{bare_druid}" }
  let(:path) { 'spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687' }
  let(:moab) { Moab::StorageObject.new(druid, path) }
  let(:workflow_client) { instance_double(Dor::Workflow::Client) }

  before do
    allow(Moab::StorageServices).to receive(:find_storage_object).with(bare_druid).and_return(moab)
    allow(Dor::Workflow::Client).to receive(:new).and_return(workflow_client)
    allow(Settings).to receive(:workflow_services_url).and_return('http://workflow')
    allow(workflow_client).to receive(:update_status).with(a_hash_including(druid: druid,
                                                                            workflow: 'preservationIngestWF',
                                                                            process: 'validate-moab')).at_least(:twice)
    allow(workflow_client).to receive(:update_error_status)
  end

  describe '#perform' do
    it 'tells workflow server check has started' do
      job.perform(druid)
      exp_str = 'Started by preservation_catalog on '
      expect(workflow_client).to have_received(:update_status).with(druid: druid,
                                                                    workflow: 'preservationIngestWF',
                                                                    process: 'validate-moab',
                                                                    status: 'started',
                                                                    note: a_string_starting_with(exp_str))
    end

    it 'reports success to workflow server when no validation errors are found' do
      allow(job).to receive(:validate).and_return([]) # test object bj102hs9687 has errors
      job.perform(druid)
      expect(workflow_client).to have_received(:update_status).twice
      exp_str = 'Completed by preservation_catalog on '
      expect(workflow_client).to have_received(:update_status).with(druid: druid,
                                                                    workflow: 'preservationIngestWF',
                                                                    process: 'validate-moab',
                                                                    elapsed: a_value > 0,
                                                                    status: 'completed',
                                                                    note: a_string_starting_with(exp_str))
    end

    it 'reports failure to workflow server when there are validation errors' do
      job.perform(druid) # test object bj102hs9687 has errors
      validation_err_substring = 'druid:bj102hs9687-v0001: version_additions: file_differences'
      expected_str_regex = /^Problem with Moab validation run on .*#{validation_err_substring}.*/
      expect(workflow_client).to have_received(:update_error_status).with(druid: druid,
                                                                          workflow: 'preservationIngestWF',
                                                                          process: 'validate-moab',
                                                                          error_msg: a_string_matching(expected_str_regex))
    end

    context 'when validation runs' do
      let(:expected_validation_err_regex) { /^Problem with Moab validation run on .*#{error_regex_str}.*/ }

      before do
        job.perform(druid)
      end

      context 'when structural validation errors' do
        let(:bare_druid) { 'zz111rr1111' }
        let(:error_regex_str) { 'expected.*druid:zz111rr1111-v0001.*found.*druid:bj102hs9687-v0001' }

        it 'sends error to workflow client' do
          expect(workflow_client).to have_received(:update_error_status).with(druid: druid,
                                                                              workflow: 'preservationIngestWF',
                                                                              process: 'validate-moab',
                                                                              error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when it fails an existence check for a manifest file' do
        let(:bare_druid) { 'zz102hs9687' }
        let(:error_regex_str) { 'expected.*druid:zz102hs9687.*version_inventory.*' }

        it 'sends error to workflow client' do
          expect(workflow_client).to have_received(:update_error_status).with(druid: druid,
                                                                              workflow: 'preservationIngestWF',
                                                                              process: 'validate-moab',
                                                                              error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when it fails an existence check for a data file' do
        let(:bare_druid) { 'dc048cw1328' }
        let(:error_regex_str) { 'expected.*druid:dc048cw1328.*versionMetadata.xml.*' }

        it 'sends error to workflow client' do
          expect(workflow_client).to have_received(:update_error_status).with(druid: druid,
                                                                              workflow: 'preservationIngestWF',
                                                                              process: 'validate-moab',
                                                                              error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when it fails a checksum verification for a manifest file' do
        let(:bare_druid) { 'zz925bx9565' }
        let(:error_regex_str) { 'zz925bx9565-v0001: version_additions: file_differences.*signatures.*"md5"' }

        it 'sends error to workflow client' do
          expect(workflow_client).to have_received(:update_error_status).with(druid: druid,
                                                                              workflow: 'preservationIngestWF',
                                                                              process: 'validate-moab',
                                                                              error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when it fails a checksum verification for a data file' do
        let(:bare_druid) { 'zz925bx9565' }
        let(:error_regex_str) { 'zz925bx9565.*versionMetadata\.xml.*signatures.*md5' }

        it 'sends error to workflow client' do
          expect(workflow_client).to have_received(:update_error_status).with(druid: druid,
                                                                              workflow: 'preservationIngestWF',
                                                                              process: 'validate-moab',
                                                                              error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when error is raised' do
        let(:expected_validation_err_regex) { /^Problem with Moab validation run on .*#{error_regex_str}.*/ }
        let(:storage_object_validator) { Stanford::StorageObjectValidator.new(moab) }
        let(:storage_object_version1) { Moab::StorageObjectVersion.new(moab, 1) }
        let(:verification_result) { Moab::VerificationResult.new('ignore_here') }

        before do
          allow(Stanford::StorageObjectValidator).to receive(:new).and_return(storage_object_validator)
          allow(storage_object_validator).to receive(:validation_errors).and_call_original
          allow(verification_result).to receive(:verified).and_return(true)
          allow(Moab::VerificationResult).to receive(:new).and_return(verification_result)
          allow(moab).to receive(:version_list).and_return([storage_object_version1])
        end

        it 'no such file error is rescued and appears in err messages' do
          allow(storage_object_version1).to receive(:verify_signature_catalog).and_raise(Errno::ENOENT, 'No such file or directory')
          job.perform(druid)
          expected_str_regex = /^Problem with Moab validation run on .*No such file or directory.*/
          expect(workflow_client).to have_received(:update_error_status).with(druid: druid,
                                                                              workflow: 'preservationIngestWF',
                                                                              process: 'validate-moab',
                                                                              error_msg: a_string_matching(expected_str_regex))
        end

        it 'Nokogiri::XML::SyntaxError is rescued and appears in err messages' do
          allow(storage_object_version1).to receive(:verify_signature_catalog).and_raise(Nokogiri::XML::SyntaxError, 'gonzo')
          job.perform(druid)
          expected_str_regex = /^Problem with Moab validation run on .*Nokogiri::XML::SyntaxError: gonzo.*/
          expect(workflow_client).to have_received(:update_error_status).with(druid: druid,
                                                                              workflow: 'preservationIngestWF',
                                                                              process: 'validate-moab',
                                                                              error_msg: a_string_matching(expected_str_regex))
        end
      end
    end
  end
end
