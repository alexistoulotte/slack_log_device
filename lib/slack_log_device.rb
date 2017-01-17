require 'active_support/core_ext/hash'
require 'active_support/core_ext/string'
require 'httparty'
require 'logger'

class SlackLogDevice

  attr_reader :flush_delay, :max_buffer_size, :timeout, :username, :webhook_url

  def initialize(options = {})
    options.assert_valid_keys(:auto_flush, :flush_delay, :max_buffer_size, :timeout, :username, :webhook_url)
    @buffer = []
    @mutex = Mutex.new
    @flush_thread
    self.auto_flush = options[:auto_flush]
    self.flush_delay = options.key?(:flush_delay) ? options[:flush_delay] : 1
    self.max_buffer_size = options.key?(:max_buffer_size) ? options[:max_buffer_size] : 8192
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
    data['username'] = username if username.present?
    begin
      HTTParty.post(webhook_url, body: data.to_json, headers: { 'Content-Type': 'application/json' }, timeout: timeout)
    rescue => e
      STDERR.puts(e)
    end
    nil
  end

  def flush?
    auto_flush? || flush_delay.zero? || @buffer.join("\n").size > max_buffer_size
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
    @flush_thread = Thread.new do
      sleep(flush_delay) unless auto_flush?
      flush
    end
    nil
  end

end
