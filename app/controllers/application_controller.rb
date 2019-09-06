# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  protected

  def strip_druid(id)
    id&.split(':', 2)&.last
  end
end
