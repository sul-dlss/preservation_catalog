# A basic logger so we can write log messages in a regular format.
class PCCLogger
  def self.log(severity, message, druid = '')
    log_message = Time.now.iso8601 + " " + druid + " " + message
    Rails.logger.add(severity, log_message)
  end
end
