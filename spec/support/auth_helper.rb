# frozen_string_literal: true

# Helper methods for testing auth related behaviors behaviors in request specs.
module AuthHelper
  def valid_auth_header
    { 'Authorization' => "Bearer #{valid_jwt_value}" }
  end

  def invalid_auth_header
    { 'Authorization' => "Bearer #{invalid_jwt_value}" }
  end

  def valid_jwt_value
    JWT.encode(jwt_payload, Settings.api_jwt.hmac_secret, 'HS512')
  end

  def invalid_jwt_value
    valid_jwt_value[0..-2] # just lop the last char off the signature to make a bad token
  end

  def jwt_payload
    { sub: 'pres-test' }
  end
end
