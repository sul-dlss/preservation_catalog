# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from Moab::ObjectNotFoundException, with: :not_found
  rescue_from Moab::InvalidSuriSyntaxError, with: :bad_request

  protected

  def strip_druid(id)
    id&.split(':', 2)&.last
  end

  def bad_request(exception)
    msg = '400 bad request'
    msg = "#{msg}: #{exception.message}" if exception
    render plain: msg, status: :bad_request
  end

  def not_found(exception)
    msg = '404 Not Found'
    msg = "#{msg}: #{exception.message}" if exception
    render plain: msg, status: :not_found
  end
end
