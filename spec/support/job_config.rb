RSpec.configure do |config|
  config.before do
    next unless RSpec.current_example.metadata[:type] == :job
    ActiveJob::Base.queue_adapter = :test
    allow(ActiveJob::Base.logger).to receive(:info) # keep the default logging quiet
  end
end
