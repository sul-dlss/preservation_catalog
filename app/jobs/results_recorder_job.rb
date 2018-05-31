# Responsibilities:
# Update DB per event info.
# Is this event the last needed for the DV to be complete?
# If NO, do nothing further.
# If YES, send a message to a non-job pub/sub queue.
class ResultsRecorderJob < ApplicationJob
  queue_as :endpoint_events
  attr_accessor :pc, :pcs

  before_perform do |job|
    job.pcs ||= PreservedCopy
                .by_druid(job.arguments.first)
                .joins(endpoint: [:endpoint_type])
                .where(
                  endpoint_types: { endpoint_class: 'archive' },
                  preserved_copies: { version: job.arguments.second }
                )
    job.pc ||= pcs.find_by!('endpoints.delivery_class' => Object.const_get(job.arguments.third))
  end

  # @param [String] druid
  # @param [Integer] version
  # @param [String] delivery_class Name of the worker class that performed delivery
  # @param [String] checksum
  def perform(druid, version, _delivery_class, _checksum)
    raise "Status shifted underneath replication: #{pc.inspect}" unless pc.unreplicated?
    pc.ok!
    return unless pcs.reload.all?(&:ok?)
    publish_result(message(druid, version).to_json)
  end

  private

  # @return [Hash] response message to enqueue
  def message(druid, version)
    {
      druid: druid,
      version: version,
      endpoints: Endpoint.where(id: pcs.pluck(:endpoint_id)).pluck(:endpoint_name)
    }
  end

  # Currently using the Resque's underlying Redis instance, but we likely would
  # want something more durable like RabbitMQ for production.
  # @param [String] message JSON
  def publish_result(message)
    # Example: RabbitMQ using `connection` from the gem "Bunny":
    # connection.create_channel.fanout('replication.results').publish(message)
    Resque.redis.redis.lpush('replication.results', message)
  end
end
