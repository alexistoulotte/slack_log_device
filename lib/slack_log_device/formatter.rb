class SlackLogDevice

  class Formatter

    MAX_MESSAGE_LENGTH = 4000

    attr_reader :extra_metadata, :max_backtrace_lines

    def initialize(options = {}, &block)
      options.assert_valid_keys(:disable_default_metadata, :extra_metadata, :max_backtrace_lines)
      self.extra_metadata = options.key?(:extra_metadata) ? options[:extra_metadata] : {}
      self.max_backtrace_lines = options.key?(:max_backtrace_lines) ? options[:max_backtrace_lines] : 10
      @disable_default_metadata = options[:disable_default_metadata].present?
      @message_converter = block_given? ? Proc.new(&block) : -> (message) { message }
    end

    def call(severity, datetime, progname, message)
      text = "*`#{severity}`*"
      text << " (*#{progname}*)" if progname.present?
      text << ':'
      if message.is_a?(Exception)
        exception = message
        text << " A `#{exception.class}` occurred: #{convert_message(exception.message)}".rstrip
        text = truncate(text)
        text = append_metadata(text, exception)
        text = append_exception_backtrace(text, exception)
        text = append_exception_cause(text, exception)
      else
        text << " #{convert_message(message)}".rstrip
        text = append_metadata(text, message)
      end
      truncate(text)
    end

    def disable_default_metadata?
      @disable_default_metadata.present?
    end

    private

    def append_exception_backtrace(text, exception)
      backtrace = format_backtrace(exception, MAX_MESSAGE_LENGTH - text.size - 2)
      backtrace.present? ? "#{text}\n\n#{backtrace}" : text
    end

    def append_exception_cause(text, exception)
      cause = exception.cause
      return text if cause.nil?
      message = "\n\nCaused by `#{exception.class}`"
      return text if (text + message).size > MAX_MESSAGE_LENGTH
      text = truncate("#{text}#{message}: #{exception.message}")
      text = append_exception_backtrace(text, cause)
      append_exception_cause(text, cause)
    end

    def append_metadata(text, message)
      metadata = format_metadata(message, MAX_MESSAGE_LENGTH - text.size - 2)
      metadata.present? ? "#{text}\n\n#{metadata}" : text
    end

    def convert_message(message)
      @message_converter.call(message.to_s.strip).to_s.strip
    end

    def default_metadata(request)
      metadata = {}
      return metadata if disable_default_metadata?
      metadata.merge!({
        'Method' => request.method,
        'URL' => request.url,
        'Remote address' => request.remote_addr,
        'User-Agent' => request.user_agent,
      }) if request.present?
      metadata.merge!({
        'User' => ENV['USER'],
        'Machine' => Socket.gethostname,
        'PID' => Process.pid,
      })
      metadata.keys.each do |key|
        value = metadata[key]
        metadata[key] = "`#{value.to_s.strip}`" if value.present?
      end
      metadata
    end

    def extra_metadata=(value)
      @extra_metadata = value.presence || {}
    end

    def format_backtrace(exception, size_available)
      return nil if max_backtrace_lines == 0 || size_available < 7
      backtrace = (exception.backtrace || []).select(&:present?).compact
      return nil if backtrace.empty?
      if max_backtrace_lines < 0
        text = backtrace.join("\n")
      else
        text = backtrace[0, max_backtrace_lines].join("\n")
        text << "\n..." if backtrace.size > max_backtrace_lines
      end
      "```#{truncate(text, size_available - 6)}```"
    end

    def format_metadata(message, size_available)
      return nil if size_available < 11
      options = {}
      options[:exception] = message if message.is_a?(Exception)
      request = Thread.current[:slack_log_device_request]
      options[:request] = request if request.present?
      text = default_metadata(request).merge(extra_metadata).map do |name, value|
        value = value.call(options) if value.respond_to?(:call)
        value.present? ? "• *#{name.strip}*: #{value.strip}" : nil
      end.compact.join("\n")
      return nil if text.blank?
      truncate(text, size_available)
    end

    def max_backtrace_lines=(value)
      length = Integer(value) rescue nil
      raise ArgumentError.new("Invalid max backtrace lines: #{value.inspect}") if length.nil? || length < -1
      @max_backtrace_lines = length
    end

    def truncate(message, max_length = MAX_MESSAGE_LENGTH)
      message = message.strip
      return message if message.size <= max_length
      return message[0, max_length] if max_length < 3
      "#{message[0, max_length - 3]}..."
    end

  end

end
