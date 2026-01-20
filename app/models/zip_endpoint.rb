# frozen_string_literal: true

# Metadata about a zip endpoint which stores zipped archives of version directories from Moab
# objects.
class ZipEndpoint < ApplicationRecord
  has_many :zipped_moab_versions, dependent: :restrict_with_exception

  validates :endpoint_name, presence: true, uniqueness: true

  delegate :bucket, :bucket_name, to: :provider

  # iterates over the zip endpoints enumerated in settings, creating a ZipEndpoint for each if one doesn't
  # already exist.
  # @return [Array<ZipEndpoint>] the ZipEndpoint list for the zip endpoints defined in the config (all
  #   entries, including any entries that may have been seeded already)
  # @note this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  def self.seed_from_config # rubocop:disable Metrics/AbcSize
    return unless Settings.zip_endpoints
    Settings.zip_endpoints.map do |endpoint_name, endpoint_config|
      find_or_create_by!(endpoint_name: endpoint_name.to_s) do |zip_endpoint|
        zip_endpoint.endpoint_node = endpoint_config.endpoint_node
        zip_endpoint.storage_location = endpoint_config.storage_location
      end
    rescue ActiveRecord::ActiveRecordError => e
      err_msg = 'Error trying to insert record for new zip endpoint, skipping entry'
      logger.warn("#{err_msg}: #{e.record.errors.full_messages}")
      Honeybadger.notify(err_msg,
                         error_class: e.class.to_s,
                         backtrace: e.backtrace,
                         context: { error_messages: e.record.errors.full_messages })
    end
  end

  def provider
    @provider ||= Replication::ProviderFactory.create(zip_endpoint: self)
  end

  def to_s
    endpoint_name
  end
end
