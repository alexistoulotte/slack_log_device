class SlackLogDevice

  module DebugExceptions

    def log_error(request, wrapper)
      logger = logger(request)
      return unless logger
      exception = wrapper.exception
      return if defined?(ActionController::RoutingError) && exception.is_a?(ActionController::RoutingError)
      exception.instance_variable_set(:@__slack_log_device_request, request)
      logger.fatal(exception)
    end

  end

end
