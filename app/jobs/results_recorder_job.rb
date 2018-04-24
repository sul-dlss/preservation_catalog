# Responsibilities:
# Update DB per event info.
# Interpret replication logic.
# Is this event the last needed for the DV to be complete?
# If NO, do nothing further.
# If YES, send a message to a non-job pub/sub queue.
class ResultsRecorderJob < ApplicationJob
  queue_as :endpoint_events

  # @param [String] druid
  # @param [Integer] version
  # @param [String] endpoint
  # @param [String] checksum
  def perform(druid, version, endpoint, checksum)
    hash = {
      druid: druid,
      version: version,
      endpoint: endpoint,
      checksum: checksum
    }
    publish_result(hash.to_json) # message could also include info about other previous events
  end

  private

  # Currently using the Resque's underlying Redis instance, but we likely would
  # want something more durable like RabbitMQ for production.
  # @param [String] message JSON
  def publish_result(message)
    # Example: RabbitMQ using `connection` from the gem "Bunny":
    # connection.create_channel.fanout('replication.results').publish(message)
    Resque.redis.redis.lpush('replication.results', message)
  end
end
