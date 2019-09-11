# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from Moab::ObjectNotFoundException, with: :not_found
  rescue_from InvalidSuriSyntax, with: :internal_server_error

  protected

  def strip_druid(id)
    id&.split(':', 2)&.last
  end

  def not_found
    render plain: '404 Not Found', status: :not_found
  end

  def internal_server_error
    render plain: '500 Internal Server Error', status: :internal_server_error
  end

  def refine_invalid_druid_error!(err)
    # make a specific moab-versioning StandardError into something more easily manageable by ApplicationController...
    raise InvalidSuriSyntax, err.message if err.message.include?('Identifier has invalid suri syntax')
    raise # ...but just re-raise what we got if it was something else
  end
end
