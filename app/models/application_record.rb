# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  # Provenance Database Logging Hack

  if Settings.provlog.enable
    after_validation :log_errors, if: proc { |m| m.errors }
    ActiveSupport::Notifications.subscribe(/active_record/) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      provlog.formatter = Logger::Formatter.new
      provlog.info "#{event.name} : #{event.payload}"
    end
  end

  def log_errors
    provlog.info errors.full_messages.join(" | ")
  end

  def self.provlog
    @provlog ||= Logger.new Rails.root.join('log', 'prov.log')
  end

  def provlog
    self.class.provlog
  end
end
