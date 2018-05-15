RSpec.configure do |config|
  config.around do |example|
    if RSpec.current_example.metadata[:live_s3]
      WebMock.disable_net_connect!(allow: /.*\.amazonaws\.com/)
      example.run
      WebMock.disable_net_connect!(allow_localhost: true)
    else
      example.run
    end
  end
end
