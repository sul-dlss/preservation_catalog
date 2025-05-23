# frozen_string_literal: true

RSpec.configure do |config|
  config.around do |example|
    if RSpec.current_example.metadata[:live_s3]
      WebMock.disable_net_connect!(allow: [/.*\.amazonaws\.com/, /.*\.storage\.googleapis\.com/, /.*\.cloud-object-storage\.appdomain\.cloud/])
      example.run
      WebMock.disable_net_connect!(allow_localhost: true)
    else
      example.run
    end
  end
end
