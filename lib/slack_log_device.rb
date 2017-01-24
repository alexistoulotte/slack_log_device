require 'active_support/core_ext/hash'
require 'active_support/core_ext/string'
require 'httparty'
require 'logger'

class SlackLogDevice

  FORMATTER = -> (severity, datetime, progname, message) do
    text = "*`#{severity}`*"
    text << " (*#{progname}*)" if progname.present?
    text << ': '
    if message.is_a?(Exception)
      text << "A `#{message.class}` occurred: #{message.message}\n\n```"
      backtrace = message.backtrace.join("\n")
      backtrace = backtrace[0, MAX_MESSAGE_LENGTH - 6 - text.size] << "..." if backtrace.size > MAX_MESSAGE_LENGTH - 3
      text << backtrace << '```'
    else
      text << message
    end
  end
  MAX_MESSAGE_LENGTH = 4000

  attr_reader :channel, :flush_delay, :max_buffer_size, :timeout, :username, :webhook_url

  def initialize(options = {})
    options.assert_valid_keys(:auto_flush, :channel, :flush_delay, :max_buffer_size, :timeout, :username, :webhook_url)
    @buffer = []
    @mutex = Mutex.new
    @flush_thread
    self.auto_flush = options[:auto_flush]
    self.channel = options[:channel]
    self.flush_delay = options.key?(:flush_delay) ? options[:flush_delay] : 1
    self.max_buffer_size = options.key?(:max_buffer_size) ? options[:max_buffer_size] : 1024 * 128
    self.timeout = options.key?(:timeout) ? options[:timeout] : 5
    self.username = options[:username]
    self.webhook_url = options[:webhook_url]
  end

  def auto_flush?
    @auto_flush
  end

  def auto_flush=(value)
    @auto_flush = value.present?
  end

  def channel=(value)
    channel = value.to_s.presence
    raise ArgumentError.new("Invalid channel specified: #{value.inspect}, it must start with # or @ and be in lower case with no spaces or special chars and its length must not exceed 22 chars") if channel && channel !~ /^[@#][a-z0-9_-]{1,21}$/
    @channel = channel
  end

  def close
    # Does nothing, this method must exist to consider the LogDevice as an IO.
  end

  def flush
    return if @buffer.empty?
    message = ''
    @mutex.synchronize do
      message = @buffer.join("\n")
      @buffer.clear
    end
    data = { 'text' => message.to_s }
    data['channel'] = channel if channel.present?
    data['username'] = username if username.present?
    begin
      HTTParty.post(webhook_url, body: data.to_json, headers: { 'Content-Type' => 'application/json' }, timeout: timeout)
    rescue Exception => e
      STDERR.puts(e)
    end
    nil
  end

  def flush?
    auto_flush? || flush_delay.zero? || @buffer.join("\n").bytesize > max_buffer_size
  end

  def flush_delay=(value)
    delay = Integer(value) rescue nil
    raise ArgumentError.new("Invalid flush delay: #{value.inspect}") if delay.nil? || delay < 0
    @flush_delay = delay
  end

  def max_buffer_size=(value)
    size = Integer(value) rescue nil
    raise ArgumentError.new("Invalid max buffer size: #{value.inspect}") if size.nil? || size < 0
    @max_buffer_size = size
  end

  def timeout=(value)
    timeout = Integer(value) rescue nil
    raise ArgumentError.new("Invalid timeout: #{value.inspect}") if timeout.nil? || timeout <= 0
    @timeout = timeout
  end

  def username=(value)
    @username = value.to_s.squish.presence
  end

  def webhook_url=(value)
    raise ArgumentError.new('Webhook URL must be specified') if value.blank?
    uri = URI(value.to_s) rescue nil
    raise ArgumentError.new("Invalid webhook URL: #{value.inspect}") if uri.nil? || !uri.is_a?(URI::HTTP)
    @webhook_url = uri.to_s
  end

  def write(message)
    message = message.to_s.try(:strip)
    return if message.blank?
    @mutex.synchronize do
      @buffer << message
    end
    @flush_thread.kill if @flush_thread
    if flush?
      flush
    else
      @flush_thread = Thread.new do
        sleep(flush_delay)
        flush
      end
    end
    nil
  end

end
