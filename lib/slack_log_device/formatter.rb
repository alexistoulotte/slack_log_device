class SlackLogDevice

  class Formatter

    DEFAULT_ICON_EMOJIS = {
      'DEBUG' => ':bug:',
      'INFO' => ':information_source:',
      'WARN' => ':warning:',
      'ERROR' => ':x:',
      'FATAL' => ':fire:',
      'UNKNOWN' => ':interrobang:',
    }.freeze
    MAX_MESSAGE_LENGTH = 4000

    attr_reader :extra_metadata, :max_backtrace_lines

    def initialize(options = {}, &block)
      options.assert_valid_keys(:disable_default_metadata, :extra_metadata, :icon_emoji, :icon_emojis, :max_backtrace_lines)
      self.disable_default_metadata = options[:disable_default_metadata]
      self.extra_metadata = options.key?(:extra_metadata) ? options[:extra_metadata] : {}
      self.max_backtrace_lines = options.key?(:max_backtrace_lines) ? options[:max_backtrace_lines] : 10

      @icon_emojis = DEFAULT_ICON_EMOJIS.dup
      self.icon_emojis = options[:icon_emojis] if options.key?(:icon_emojis)
      self.icon_emoji = options[:icon_emoji] if options.key?(:icon_emoji)

      @message_converter = block_given? ? Proc.new(&block) : -> (message) { message }
    end

    def call(severity, _datetime, progname, message)
      text = "*`#{severity}`*"
      text << " (*#{to_utf8(progname)}*)" if progname.present?
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
      Message.new(truncate(text), icon_emoji: icon_emoji(severity))
    end

    def disable_default_metadata=(value)
      @disable_default_metadata = value.present?
    end

    def disable_default_metadata?
      @disable_default_metadata
    end

    def extra_metadata=(value)
      @extra_metadata = (value.presence || {})
    end

    def icon_emoji(severity)
      @icon_emojis[parse_severity(severity)]
    end

    def icon_emoji=(value)
      value = value.to_s.strip.presence
      @icon_emojis.each_key do |severity|
        @icon_emojis[severity] = value
      end
    end

    def icon_emojis
      @icon_emojis.freeze
    end

    def icon_emojis=(values = {})
      values.each do |severity, emoji|
        @icon_emojis[parse_severity(severity)] = emoji.to_s.strip.presence
      end
    end

    def max_backtrace_lines=(value)
      length = Integer(value) rescue nil
      raise ArgumentError.new("Invalid max backtrace lines: #{value.inspect}") if length.nil? || length < -1
      @max_backtrace_lines = length
    end

    private

    def append_exception_backtrace(text, exception)
      backtrace = format_backtrace(exception, MAX_MESSAGE_LENGTH - text.size - 2)
      backtrace.present? ? "#{to_utf8(text)}\n\n#{backtrace}" : text
    end

    def append_exception_cause(text, exception)
      cause = exception.cause
      text = to_utf8(text)
      return text if cause.nil?
      message = "\n\nCaused by `#{cause.class}`"
      return text if (text + message).size > MAX_MESSAGE_LENGTH
      text = truncate("#{text}#{message}: #{to_utf8(cause.message)}")
      text = append_exception_backtrace(text, cause)
      append_exception_cause(text, cause)
    end

    def append_metadata(text, message)
      metadata = format_metadata(message, MAX_MESSAGE_LENGTH - text.size - 2)
      metadata.present? ? "#{to_utf8(text)}\n\n#{metadata}" : text
    end

    def convert_message(message)
      to_utf8(@message_converter.call(to_utf8(message.to_s.strip)).to_s.strip)
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
      metadata.each_key do |key|
        value = metadata[key]
        metadata[key] = "`#{to_utf8(value.to_s.strip)}`" if value.present?
      end
      metadata
    end

    def format_backtrace(exception, size_available)
      return nil if max_backtrace_lines == 0 || size_available < 7
      backtrace = (exception.backtrace || []).select(&:present?).compact.map { |line| to_utf8(line) }
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
        value.present? ? "• *#{to_utf8(name).strip}*: #{to_utf8(value).strip}" : nil
      end.compact.join("\n")
      return nil if text.blank?
      truncate(text, size_available)
    end

    def parse_severity(value)
      severity = value.to_s.strip.upcase
      return severity if DEFAULT_ICON_EMOJIS.key?(severity)
      raise("Invalid log severity: #{value.inspect}")
    end

    def truncate(message, max_length = MAX_MESSAGE_LENGTH)
      message = message.strip
      return message if message.size <= max_length
      return message[0, max_length] if max_length < 3
      to_utf8("#{message[0, max_length - 3]}...")
    end

    def to_utf8(text)
      return text if text.nil? || text.encoding == Encoding::UTF_8
      text.encode(Encoding::UTF_8) rescue text.dup.force_encoding(Encoding::UTF_8)
    end

  end

end

require "#{__dir__}/formatter/message"
