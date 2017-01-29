require 'action_dispatch/http/request'

class SlackLogDevice

  class SetRequestInThread

    def initialize(app)
      @app = app
    end

    def call(env)
      Thread.current[:slack_log_device_request] = ActionDispatch::Request.new(env)
      @app.call(env)
    end

  end

end
