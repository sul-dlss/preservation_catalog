class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  # Provenance Database Logging Hack
  $provlogger = Logger.new Rails.root.join('log/test.log')

  if Settings.provlog.enable
    after_validation :log_errors, :if => Proc.new {|m| m.errors}
    ActiveSupport::Notifications.subscribe /active_record/ do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      $provlogger.formatter = Logger::Formatter.new
      $provlogger.info "#{event.name} : #{event.payload}"
    end
  end

  def log_errors
    $provlogger.info self.errors.full_messages.join(" | ")
  end
end
