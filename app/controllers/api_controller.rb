# frozen_string_literal: true

# for API endpoints; for browser endpoints, see ApplicationController
class ApiController < ActionController::API
  include ActionController::MimeResponds

  before_action :check_auth_token!

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from Moab::ObjectNotFoundException, with: :not_found
  rescue_from Moab::InvalidSuriSyntaxError, with: :bad_request

  TOKEN_HEADER = 'Authorization'

  private

  # IMPORTANT!  all non-API routes must be protected by shibboleth and restricted to an
  # appropritaly small workgroup.
  def non_api_route?
    # no need to list /status (okcomputer) URLs here, because those aren't handled by ApplicationController
    request.fullpath.match(%r{^/(queues)|(dashboard)(/.*)?$})
  end

  def check_auth_token!
    return if non_api_route?

    unless bearer_token
      log_and_notify("no #{TOKEN_HEADER} token was provided by #{request.remote_ip}")
      return render json: { error: 'Not Authorized' }, status: :unauthorized
    end

    decoded_jwt = decode_bearer_token!
    Honeybadger.context(invoked_by: decoded_jwt[:sub])
  rescue StandardError => e
    log_and_notify("error validating bearer token #{bearer_token} provided by #{request.remote_ip}: #{e}")
    render json: { error: 'Not Authorized' }, status: :unauthorized
  end

  def decode_bearer_token!
    token = bearer_token
    body = JWT.decode(token, Settings.api_jwt.hmac_secret, true, algorithm: 'HS512').first
    ActiveSupport::HashWithIndifferentAccess.new body
  end

  def bearer_token
    return nil if request.headers[TOKEN_HEADER].blank?

    request.headers[TOKEN_HEADER].sub(/^Bearer /, '')
  end

  def strip_druid(id)
    id&.split(':', 2)&.last
  end

  def not_found(exception)
    msg = '404 Not Found'
    msg = "#{msg}: #{exception.message}" if exception
    render plain: msg, status: :not_found
  end

  def log_and_notify(msg)
    Rails.logger.warn(msg)
    Honeybadger.notify(msg)
  end
end
