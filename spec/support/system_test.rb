# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test # rack_test by default, for performance
  end

  config.before(:each, :js, type: :system) do
    driven_by :selenium_chrome_headless # selenium when we need javascript
  end
end
