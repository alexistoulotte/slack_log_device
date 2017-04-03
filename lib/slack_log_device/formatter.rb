class SlackLogDevice

  class Formatter

    MAX_MESSAGE_LENGTH = 4000

    attr_reader :extra_metadata

    def initialize(options = {}, &block)
      options.assert_valid_keys(:extra_metadata)
      @extra_metadata = options.key?(:extra_metadata) ? options[:extra_metadata] : {}
      @message_converter = block_given? ? Proc.new(&block) : -> (message) { message }
    end

    def call(severity, datetime, progname, message)
      text = "*`#{severity}`*"
      text << " (*#{progname}*)" if progname.present?
      text << ':'
      if message.is_a?(Exception)
        exception = message
        text << " A `#{message.class}` occurred: #{convert_message(exception.message)}".rstrip
        text = truncate(text)
        text = append_metadata(text, exception)
        text = append_backtrace(text, exception)
      else
        text << " #{convert_message(message)}".rstrip
        text = append_metadata(text, message)
      end
      truncate(text)
    end

    private

    def append_backtrace(text, exception)
      backtrace = format_backtrace(exception, MAX_MESSAGE_LENGTH - text.size - 2)
      text << "\n\n" << backtrace if backtrace.present?
      text
    end

    def append_metadata(text, message)
      metadata = format_metadata(message, MAX_MESSAGE_LENGTH - text.size - 2)
      text << "\n\n" << metadata if metadata.present?
      text
    end

    def convert_message(message)
      @message_converter.call(message.to_s.strip).to_s.strip
    end

    def default_metadata(request)
      return {} if request.blank?
      metadata = {
        'Method' => request.method,
        'URL' => request.url,
        'Remote address' => request.remote_addr,
        'User-Agent' => request.user_agent,
      }
      metadata.keys.each do |key|
        value = metadata[key]
        metadata[key] = "`#{value.strip}`" if value.present?
      end
      metadata
    end

    def format_backtrace(exception, size_available)
      backtrace = exception.backtrace.try(:join, "\n")
      return nil if backtrace.blank? || size_available < 7
      "```#{truncate(backtrace, size_available - 6)}```"
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

    def truncate(message, max_length = MAX_MESSAGE_LENGTH)
      message = message.strip
      return message if message.size <= max_length
      return message[0, max_length] if max_length < 3
      "#{message[0, max_length - 3]}..."
    end

  end

end
