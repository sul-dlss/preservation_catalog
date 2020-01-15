# frozen_string_literal: true

desc 'Generate a JWT token for authentication'
task generate_token: :environment do
  print 'Account name: '
  name = $stdin.gets.chomp
  payload = { sub: name }
  puts "Your token:\n#{JWT.encode(payload, Settings.api_jwt.hmac_secret, 'HS512')}"
end
