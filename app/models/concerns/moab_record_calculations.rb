# frozen_string_literal: true

# Methods for calculating aggregations on MoabRecords.
# These are separated from the main MoabRecord class for clarity.
module MoabRecordCalculations
  extend ActiveSupport::Concern
  include InstrumentationSupport

  ERROR_STATUSES = %w[invalid_moab
                      invalid_checksum
                      moab_on_storage_not_found
                      unexpected_version_on_storage].freeze

  MoabRecordsByMoabStorageRootResult = Struct.new('MoabRecordsByMoabStorageRootResult',
                                                  :moab_storage_root,
                                                  :total_size,
                                                  :moab_count,
                                                  :ok_count,
                                                  :invalid_moab_count,
                                                  :invalid_checksum_count,
                                                  :moab_on_storage_not_found_count,
                                                  :unexpected_version_on_storage_count,
                                                  :validity_unknown_count,
                                                  keyword_init: true) do
                                                    def initialize(**kwargs) # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
                                                      super
                                                      self.total_size ||= 0
                                                      self.moab_count ||= 0
                                                      self.ok_count ||= 0
                                                      self.invalid_moab_count ||= 0
                                                      self.invalid_checksum_count ||= 0
                                                      self.moab_on_storage_not_found_count ||= 0
                                                      self.unexpected_version_on_storage_count ||= 0
                                                      self.validity_unknown_count ||= 0
                                                    end
                                                  end

  included do
    # @return [ActiveRecord::Relation<MoabRecord>] MoabRecords with error statuses
    scope :with_errors, -> { where(status: ERROR_STATUSES).annotate(caller) }

    # @return [ActiveRecord::Relation<MoabRecord>] MoabRecords with status of validity_unknown for more than a week
    scope :stuck, lambda {
      where(status: 'validity_unknown').where(updated_at: ...1.week.ago).annotate(caller)
    }
  end

  class_methods do # rubocop:disable Metrics/BlockLength
    # @return [Integer] count of MoabRecords with status of validity_unknown
    def validity_unknown_count
      where(status: 'validity_unknown')
        .annotate(caller)
        .count
    end

    # @return [Integer] count of MoabRecords with checksum validation audits with grace period
    def expired_checksum_validation_with_grace_count
      where(last_checksum_validation: ...(Time.current - Settings.preservation_policy.fixity_ttl.seconds - 7.days))
        .annotate(caller)
        .count
    end

    # @return [Array<MoabRecordsByMoabStorageRootResult>, MoabRecordsByMoabStorageRootResult] aggregation of MoabRecords by MoabStorageRoot
    #   and a total aggregation
    def moab_records_by_moab_storage_root # rubocop:disable Metrics/AbcSize
      result_map = {}
      total_result = MoabRecordsByMoabStorageRootResult.new(moab_count: 0)
      MoabStorageRoot.find_each do |moab_storage_root|
        result_map[moab_storage_root.id] = MoabRecordsByMoabStorageRootResult.new(
          moab_storage_root: moab_storage_root
        )
      end
      group(:moab_storage_root_id).count.each do |moab_storage_root_id, count|
        result_map[moab_storage_root_id].moab_count = count
        total_result.moab_count += count
      end
      group(:moab_storage_root_id).sum(:size).each do |moab_storage_root_id, size|
        result_map[moab_storage_root_id].total_size = size || 0
        total_result.total_size += size || 0
      end
      group(:moab_storage_root_id, :status).count.each do |(moab_storage_root_id, status), count|
        count_method = "#{status}_count"
        result_map[moab_storage_root_id].public_send("#{count_method}=", count)
        total_count = total_result.public_send(count_method)
        total_result.public_send("#{count_method}=", total_count + count)
      end
      [result_map.values, total_result]
    end
  end
end
