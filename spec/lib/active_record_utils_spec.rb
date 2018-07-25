require 'rails_helper'

require 'active_record_utils.rb'
require 'audit_results.rb'

RSpec.describe ActiveRecordUtils do
  describe '.with_transaction_and_rescue' do
    let(:audit_results) { instance_double(AuditResults) }

    it 'returns true when the transaction finishes successfully (and adds no results)' do
      expect(audit_results).not_to receive(:add_result)
      tx_result = described_class.with_transaction_and_rescue(audit_results) do
        MoabStorageRoot.count
      end
      expect(tx_result).to eq true
    end
    it 'adds DB_OBJ_DOES_NOT_EXIST result and returns false when the transaction raises RecordNotFound' do
      expect(audit_results).to receive(:add_result).with(
        AuditResults::DB_OBJ_DOES_NOT_EXIST, a_string_matching("Couldn't find MoabStorageRoot")
      )
      tx_result = described_class.with_transaction_and_rescue(audit_results) do
        MoabStorageRoot.find(-1)
      end
      expect(tx_result).to eq false
    end
    it 'adds DB_UPDATE_FAILED result and returns false when the transaction raises ActiveRecordError' do
      expect(audit_results).to receive(:add_result).with(
        AuditResults::DB_UPDATE_FAILED, a_string_matching('ActiveRecord::InvalidForeignKey')
      )
      tx_result = described_class.with_transaction_and_rescue(audit_results) do
        PreservationPolicy.default_policy.delete
      end
      expect(tx_result).to eq false
    end
    it 'lets an unexpected error bubble up' do
      expect do
        described_class.with_transaction_and_rescue(audit_results) do
          PreservationPolicy.not_a_real_method
        end
      end.to raise_error(NoMethodError)
    end
  end

  describe '.process_in_batches' do
    let(:batch_size) { 2 }
    let(:num_objs) { 9 }
    let(:expect_num_batches) do
      # integer division returns an integer.  add a cleanup batch if there's any remainder.
      (num_objs % batch_size == 0) ? (num_objs / batch_size) : (num_objs / batch_size + 1)
    end
    let(:ms_root) { MoabStorageRoot.find_by(name: 'fixture_sr1') }

    it 'processes the all of the relation results in order' do
      comp_moabs_to_process = (1..num_objs).map do |n|
        po = PreservedObject.create!(
          druid: "zy123cd456#{n}", current_version: 1, preservation_policy: PreservationPolicy.default_policy
        )
        CompleteMoab.create!(
          preserved_object: po,
          moab_storage_root: ms_root,
          version: 1,
          status: 'validity_unknown'
        )
      end
      # we're going to query by creation date descending, since DBs often return in order of create or upd date in
      # the absence of sort criteria (we just want to be extra sure in testing that our order by clause is respected).
      expected_ids = comp_moabs_to_process.map(&:id).reverse

      relation = CompleteMoab
                 .where(moab_storage_root: ms_root, status: 'validity_unknown')
                 .order(created_at: :desc)
      allow(relation).to receive(:limit).with(batch_size).and_call_original

      actual_ids = []
      described_class.process_in_batches(relation, batch_size) do |row|
        actual_ids << row.id
        row.update!(status: 'ok')
      end

      expect(relation).to have_received(:limit).with(batch_size).exactly(expect_num_batches).times
      expect(actual_ids).to eq expected_ids
    end
  end
end
