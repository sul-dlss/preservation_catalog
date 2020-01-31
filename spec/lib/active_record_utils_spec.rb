# frozen_string_literal: true

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
end
