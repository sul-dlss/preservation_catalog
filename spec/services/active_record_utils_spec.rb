# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveRecordUtils do
  describe '.with_transaction_and_rescue' do
    let(:audit_results) { instance_double(AuditResults) }

    it 'returns true when the transaction finishes successfully (and adds no results)' do
      expect(audit_results).not_to receive(:add_result)
      tx_result = described_class.with_transaction_and_rescue(audit_results) do
        MoabStorageRoot.count
      end
      expect(tx_result).to be true
    end

    it 'adds DB_OBJ_DOES_NOT_EXIST result and returns false when the transaction raises RecordNotFound' do
      expect(audit_results).to receive(:add_result).with(
        AuditResults::DB_OBJ_DOES_NOT_EXIST, a_string_matching("Couldn't find MoabStorageRoot")
      )
      tx_result = described_class.with_transaction_and_rescue(audit_results) do
        MoabStorageRoot.find(-1)
      end
      expect(tx_result).to be false
    end

    it 'lets an unexpected error bubble up' do
      expect do
        described_class.with_transaction_and_rescue(audit_results) do
          MoabStorageRoot.not_a_real_method
        end
      end.to raise_error(NoMethodError)
    end
  end
end
