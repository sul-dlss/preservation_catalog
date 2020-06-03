# frozen_string_literal: true

# some useful re-usable ActiveRecord patterns
module ActiveRecordUtils
  # Executes the given block in an ActiveRecord transaction.  Traps common ActiveRecord exceptions.
  # @param [AuditResults] for appending a result when the block raises a common AR exception.
  # @return true if transaction completed without error; false if ActiveRecordError was raised
  def self.with_transaction_and_rescue(audit_results)
    begin
      ApplicationRecord.transaction { yield }
      return true
    rescue ActiveRecord::RecordNotFound => e
      audit_results.add_result(AuditResults::DB_OBJ_DOES_NOT_EXIST, e.inspect)
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("db update error; more context to follow: #{e.inspect}: #{e.backtrace.inspect}")
      audit_results.add_result(
        AuditResults::DB_UPDATE_FAILED, e.inspect
      )
    end
    false
  end
end
