RSpec.configure do |config|
  config.around do |example|
    if RSpec.current_example.metadata[:live_aws] || RSpec.current_example.metadata[:live_ibm]
      WebMock.disable_net_connect!(allow: [/.*\.amazonaws\.com/, /.*\.cloud\.ibm\.com[:443]?/])
      example.run
      WebMock.disable_net_connect!(allow_localhost: true)
    else
      example.run
    end
  end
end
