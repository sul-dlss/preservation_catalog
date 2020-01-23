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

  # Process all results of the given AR relation, batch_size records at a time (runs the given block on each result).
  # Somewhat similar purpose to find_each and similar methods, but with two big differences:
  # - Respects the order of the given relation
  # - Grabs the *first* batch_size results on every while loop iteration.  The assumption is that the given block
  #   will update each record such that the query won't return it on the next iteration (e.g. relation is a query
  #   for objects that need to be fixity checked, and the block marks each object it encounters as checked). In
  #   other words, the "window" doesn't advance over the result set on each iteration, rather the result set
  #   is expected to "lose" the previously processed results on each iteration.
  # see also http://api.rubyonrails.org/classes/ActiveRecord/Batches.html
  def self.process_in_batches(relation, batch_size)
    # Note that this will try to re-run the query for as many batches as were available when the count was
    # first obtained.  As the above link reminds us, "By its nature, batch processing is subject to race conditions
    # if other processes are modifying the database."
    num_to_process = relation.count
    while num_to_process.positive?
      relation.limit(batch_size).each do |row|
        yield row
      end
      num_to_process -= batch_size
    end
  end
end
