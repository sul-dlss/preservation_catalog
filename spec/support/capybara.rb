# frozen_string_literal: true

RSpec.configure do |config|
  config.prepend_before(:example, type: :system) do
    # Rack tests are faster than Selenium, but they don't support JavaScript
    driven_by :rack_test
  end
end
