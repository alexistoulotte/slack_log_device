require File.expand_path("#{__dir__}/../lib/slack_log_device")
require 'byebug'

RSpec.configure do |config|
  config.before(:each) do
    Thread.current[:slack_log_device_request] = nil
    allow(HTTParty).to receive(:post)
  end

  config.raise_errors_for_deprecations!
end
