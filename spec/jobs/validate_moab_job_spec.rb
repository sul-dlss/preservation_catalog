# frozen_string_literal: true

require 'rails_helper'

describe ValidateMoabJob do
  let(:job) { described_class.new }
  let(:bare_druid) { 'bj102hs9687' }
  let(:druid) { "druid:#{bare_druid}" }
  let(:path) { 'spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687' }
  let(:moab) { Moab::StorageObject.new(druid, path) }
  let(:object_client) { instance_double(Dor::Services::Client::Object, workflow: object_workflow) }
  let(:object_workflow) { instance_double(Dor::Services::Client::ObjectWorkflow, process:) }
  let(:process) { instance_double(Dor::Services::Client::Process, update: true, update_error: true) }

  before do
    allow(Moab::StorageServices).to receive(:find_storage_object).with(druid).and_return(moab)
    allow(Dor::Services::Client).to receive(:object).with(druid).and_return(object_client)
  end

  describe '#perform' do
    it 'uses full druid when it gets full druid' do
      job.perform(druid)
      expect(job.druid).to eq druid
    end

    it 'uses full druid when it gets bare druid' do
      job.perform(bare_druid)
      expect(job.druid).to eq druid
    end

    it 'tells workflow server check has started' do
      job.perform(druid)
      exp_str = 'Started by preservation_catalog on '
      expect(process).to have_received(:update).with(status: 'started',
                                                     note: a_string_starting_with(exp_str))
    end

    it 'reports success to workflow server when no validation errors are found' do
      allow(job).to receive(:validate).and_return([]) # test object bj102hs9687 has errors
      job.perform(druid)
      expect(process).to have_received(:update).twice
      exp_str = 'Completed by preservation_catalog on '
      expect(process).to have_received(:update).with(elapsed: a_value > 0,
                                                     status: 'completed',
                                                     note: a_string_starting_with(exp_str))
    end

    it 'reports failure to workflow server when there are validation errors' do
      # ensure test object bj102hs9687 has expected errors
      allow(job).to receive(:validate).and_return(job.send(:verification_errors, moab.version_list.first.verify_version_storage))
      job.perform(druid) # test object bj102hs9687 has errors
      validation_err_substring = 'druid:bj102hs9687-v0001: version_additions: file_differences'
      expected_str_regex = /^Problem with Moab validation run on .*#{validation_err_substring}.*/
      expect(process).to have_received(:update_error).with(error_msg: a_string_matching(expected_str_regex))
    end

    it 'sleeps' do
      expect_any_instance_of(described_class).to receive(:sleep).with(Settings.filesystem_delay_seconds)
      job.perform(druid)
    end

    context 'when validation runs' do
      let(:expected_validation_err_regex) { /^Problem with Moab validation run on .*#{error_regex_str}.*/ }

      context 'when structural validation errors' do
        let(:bare_druid) { 'zz111rr1111' }
        let(:error_regex_str) { 'expected.*druid:zz111rr1111-v0001.*found.*druid:bj102hs9687-v0001' }

        it 'sends error to workflow client' do
          job.perform(druid)
          expect(process).to have_received(:update_error).with(error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when it fails an existence check for a manifest file in any version' do
        let(:bare_druid) { 'zz102hs9687' }
        let(:path) { 'spec/fixtures/checksum_root01/sdr2objects/zz/102/hs/9687/zz102hs9687' }
        let(:error_regex_str) { 'expected.*druid:zz102hs9687.*found.*druid:bj102hs9687-v0001.*version_inventory.*' }

        it 'sends error to workflow client' do
          job.perform(druid)
          expect(process).to have_received(:update_error).with(error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when it fails an existence check for a data file in any version' do
        let(:bare_druid) { 'tt222tt2222' }
        let(:path) { 'spec/fixtures/checksum_root01/sdr2objects/tt/222/tt/2222/tt222tt2222' }
        let(:error_regex_str) { 'missing.*tt222tt2222/v0001/data/content/SC1258_FUR_032a.jpg.*' }
        let(:erroring_version) { moab.version_list.first }

        before do
          # ensure validate encounters the proper errors
          allow(job).to receive(:validate).and_return(job.send(:verification_errors, moab.version_list.last.verify_signature_catalog))
        end

        it 'sends error to workflow client' do
          job.perform(druid)
          expect(process).to have_received(:update_error).with(error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when it fails a checksum verification for a manifest file in any version' do
        let(:bare_druid) { 'zz925bx9565' }
        let(:error_regex_str) { 'zz925bx9565-v0001: version_additions: file_differences.*metadata.*versionMetadata.xml.*md5' }

        before do
          # ensure validate encounters the proper errors
          allow(job).to receive(:validate).and_return(job.send(:verification_errors, moab.version_list.first.verify_version_storage))
        end

        it 'sends error to workflow client' do
          job.perform(druid)
          expect(process).to have_received(:update_error).with(error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when it fails a checksum verification for a data file in most recent version' do
        let(:bare_druid) { 'yg880zm4762' }
        let(:path) { 'spec/fixtures/checksum_root01/sdr2objects/yg/880/zm/4762/yg880zm4762' }
        let(:error_regex_str) { '.*version_additions: file_differences.*yg880zm4762.*content.*36105016577111-gb-hocr.zip.*md5' }

        before do
          # validate step only returns the error of interest
          allow(job).to receive(:validate).and_return(job.send(:verification_errors, moab.version_list.first.verify_version_additions))
        end

        it 'sends error to workflow client' do
          job.perform(druid)
          expect(process).to have_received(:update_error).with(error_msg: a_string_matching(expected_validation_err_regex))
        end
      end

      context 'when validating versions' do
        let(:oldest_storage_obj_version) { moab.version_list.first }
        let(:newest_storage_obj_version) { moab.version_list.last }

        before do
          allow(oldest_storage_obj_version).to receive(:verify_signature_catalog).and_call_original
          allow(oldest_storage_obj_version).to receive(:verify_version_storage).and_call_original
          allow(oldest_storage_obj_version).to receive(:verify_manifest_inventory).and_call_original
          allow(oldest_storage_obj_version).to receive(:verify_version_inventory).and_call_original
          allow(oldest_storage_obj_version).to receive(:verify_version_additions).and_call_original
          allow(newest_storage_obj_version).to receive(:verify_signature_catalog).and_call_original
          allow(newest_storage_obj_version).to receive(:verify_version_storage).and_call_original
          allow(newest_storage_obj_version).to receive(:verify_manifest_inventory).and_call_original
          allow(newest_storage_obj_version).to receive(:verify_version_inventory).and_call_original
          allow(newest_storage_obj_version).to receive(:verify_version_additions).and_call_original
          allow(moab).to receive(:version_list).and_return([oldest_storage_obj_version, newest_storage_obj_version])
          job.perform(druid) # yes, we're doing it again
        end

        it 'calls #verify_signature_catalog' do
          expect(oldest_storage_obj_version).to have_received(:verify_signature_catalog)
          expect(newest_storage_obj_version).to have_received(:verify_signature_catalog)
        end

        context 'when most recent version of Moab' do
          it 'calls #verify_version_storage to include checksum validations' do
            expect(newest_storage_obj_version).to have_received(:verify_version_storage)
          end

          it 'calls #verify_manifest_inventory (via verify_version_storage)' do
            expect(newest_storage_obj_version).to have_received(:verify_manifest_inventory)
          end

          it 'calls #verify_version_inventory (via verify_version_storage)' do
            expect(newest_storage_obj_version).to have_received(:verify_version_inventory)
          end

          it 'calls #verify_version_additions (via verify_version_storage)' do
            expect(newest_storage_obj_version).to have_received(:verify_version_additions)
          end
        end

        context 'when older version of Moab' do
          it 'does not call #verify_version_storage' do
            expect(oldest_storage_obj_version).not_to have_received(:verify_version_storage)
          end

          it 'calls #verify_manifest_inventory' do
            expect(oldest_storage_obj_version).to have_received(:verify_manifest_inventory)
          end

          it 'calls #verify_version_inventory' do
            expect(oldest_storage_obj_version).to have_received(:verify_version_inventory)
          end

          it 'does not call #verify_version_additions (no data file checksum comparisons)' do
            expect(oldest_storage_obj_version).not_to have_received(:verify_version_additions)
          end
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
          expect(process).to have_received(:update_error).with(error_msg: a_string_matching(expected_str_regex))
        end

        it 'Nokogiri::XML::SyntaxError is rescued and appears in err messages' do
          allow(storage_object_version1).to receive(:verify_signature_catalog).and_raise(Nokogiri::XML::SyntaxError, 'gonzo')
          job.perform(druid)
          expected_str_regex = /^Problem with Moab validation run on .*Nokogiri::XML::SyntaxError: gonzo.*/
          expect(process).to have_received(:update_error).with(error_msg: a_string_matching(expected_str_regex))
        end
      end
    end
  end
end
