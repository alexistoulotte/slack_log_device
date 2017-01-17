require 'active_support/core_ext/hash'
require 'active_support/core_ext/string'
require 'httparty'
require 'logger'

class SlackLogDevice

  attr_reader :timeout, :username, :webhook_url

  def initialize(options = {})
    options.assert_valid_keys(:timeout, :username, :webhook_url)
    self.timeout = options.key?(:timeout) ? options[:timeout] : 5
    self.username = options[:username]
    self.webhook_url = options[:webhook_url]
  end

  def close
    # Does nothing, this method must exist to consider the LogDevice as an IO.
  end

  def timeout=(value)
    timeout = Integer(value) rescue nil
    raise ArgumentError.new("Invalid timeout: #{value.inspect}") if timeout.nil?
    @timeout = timeout
  end

  def username=(value)
    @username = value.to_s.squish.presence
  end

  def webhook_url=(value)
    raise ArgumentError.new('Webhook URL must be specified') if value.blank?
    uri = URI(value.to_s) rescue nil
    raise ArgumentError.new("Invalid Webhook URL: #{value.inspect}") if uri.nil? || !uri.is_a?(URI::HTTP)
    @webhook_url = uri.to_s
  end

  def write(message)
    message = message.to_s.try(:strip)
    return if message.blank?
    data = { 'text' => message.to_s }
    data['username'] = username if username.present?
    HTTParty.post(webhook_url, body: data.to_json, headers: { 'Content-Type': 'application/json' }, timeout: timeout)
    nil
  end

end
