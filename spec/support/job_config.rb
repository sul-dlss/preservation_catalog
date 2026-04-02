# frozen_string_literal: true

RSpec.configure do |config|
  config.include ActiveJob::TestHelper, type: :job

  config.before do
    next unless RSpec.current_example.metadata[:type] == :job

    allow(ActiveJob::Base.logger).to receive(:info) # keep the default logging quiet
  end
end
