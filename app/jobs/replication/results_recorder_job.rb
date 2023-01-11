# frozen_string_literal: true

module Replication
  # Preconditions: ZipPart exists in database
  #
  # Responsibilities:
  # 1. Update ZipPart status in database.
  # 2. when all zip parts for the druid version are delivered to ONE endpoint,
  #   Report to DOR event service
  # 3. when all zip parts for the druid version are delivered to ALL endpoints,
  #   Publish a message to a non-job pub/sub queue (currently no consumers).
  class ResultsRecorderJob < ApplicationJob
    queue_as :zip_endpoint_events
    attr_accessor :zmv, :zmvs

    before_perform do |job|
      job.zmvs ||= ZippedMoabVersion
                   .by_druid(job.arguments.first)
                   .joins(:zip_endpoint)
                   .where(version: job.arguments.second)
      job.zmv ||= zmvs.find_by!(zip_endpoints: { delivery_class: job.arguments.fourth })
    end

    include UniqueJob

    # @param [String] druid
    # @param [Integer] version
    # @param [String] s3_part_key
    # @param [String] delivery_class Name of the worker class that performed delivery
    def perform(druid, version, s3_part_key, delivery_class) # rubocop:disable Lint/UnusedMethodArgument # delivery_class used as job.arguments.fourth in before_perform
      part = zip_part!(s3_part_key)
      part.ok!

      # log to event service if all ZipParts are replicated for THIS endpoint
      create_zmv_replicated_event(druid) if zmv.reload.all_parts_replicated?

      # only publish result if ALL of ZipParts are replicated to ALL zip_endpoints
      return unless zmvs.reload.all?(&:all_parts_replicated?)

      publish_result(message(druid, version).to_json)
    end

    private

    def zip_part!(s3_part_key)
      zmv.zip_parts.find_by!(
        suffix: File.extname(s3_part_key),
        status: 'unreplicated'
      )
    end

    # @return [Hash] response message to enqueue
    def message(druid, version)
      {
        druid: druid,
        version: version,
        zip_endpoints: zmvs.pluck(:endpoint_name).sort
      }
    end

    # If there are consumers for this, we might want something more durable than
    #   Sidekiq's underlying redis instance (e.g. RabbitMQ).
    # @param [String] message JSON
    def publish_result(message)
      # Example: RabbitMQ using `connection` from the gem "Bunny":
      # connection.create_channel.fanout('replication.results').publish(message)
      Sidekiq.redis { |redis| redis.lpush('replication.results', message) }
    end

    def create_zmv_replicated_event(druid)
      parts_info = zmv.zip_parts.order(:suffix).map do |part|
        { s3_key: part.s3_key, size: part.size, md5: part.md5 }
      end

      Dor::Event::Client.create(
        druid: "druid:#{druid}",
        type: 'druid_version_replicated',
        data: {
          host: Socket.gethostname,
          invoked_by: 'preservation-catalog',
          version: zmv.version,
          endpoint_name: zmv.zip_endpoint.endpoint_name,
          parts_info: parts_info
        }
      )
    end
  end
end
