require 'spec_helper'

describe SlackLogDevice do

  let(:device) { SlackLogDevice.new(options) }
  let(:logger) { Logger.new(device).tap { |logger| logger.level = Logger::INFO } }
  let(:options) { { username: 'MyApp', webhook_url: 'https://hooks.slack.com/services/test' } }

  describe '#close' do

    it 'does nothing' do
      expect {
        device.close
      }.not_to raise_error
    end

  end

  describe '#initialize' do

    it 'raise an error if an invalid option is given' do
      expect {
        SlackLogDevice.new(foo: 'bar')
      }.to raise_error(ArgumentError, "Unknown key: :foo. Valid keys are: :timeout, :username, :webhook_url")
    end

    it 'raise an error if webhook option is not given' do
      expect {
        SlackLogDevice.new(options.except(:webhook_url))
      }.to raise_error(ArgumentError, 'Webhook URL must be specified')
    end

  end

  describe '#timeout' do

    it 'is 5 by default' do
      expect(device.timeout).to eq(5)
    end

    it 'can be specified' do
      options[:timeout] = 10
      expect(device.timeout).to be(10)
    end

    it 'raise an error if invalid' do
      options[:timeout] = 'foo'
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid timeout: "foo"')
    end

    it 'is default value if blank' do
      options[:timeout] = ' '
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid timeout: " "')
    end

    it 'raise an error if set as nil' do
      expect {
        device.timeout = nil
      }.to raise_error(ArgumentError, 'Invalid timeout: nil')
    end

    it 'can be specified as string' do
      options[:timeout] = '42'
      expect(device.timeout).to eq(42)
    end

    it 'can be set' do
      expect {
        device.timeout = 15
      }.to change { device.timeout }.from(5).to(15)
    end

  end

  describe '#username' do

    it 'is username set at initialization' do
      expect(device.username).to eq('MyApp')
    end

    it 'is nil if not specified' do
      device = SlackLogDevice.new(options.except(:username))
      expect(device.username).to be_nil
    end

    it 'is squished' do
      options[:username] = "John   Doe\n "
      expect(device.username).to eq('John Doe')
    end

    it 'is nil if blank' do
      options[:username] = " \n"
      expect(device.username).to be_nil
    end

    it 'can be set' do
      expect {
        device.username = 'John Doe'
      }.to change { device.username }.from(options[:username]).to('John Doe')
    end

  end

  describe '#webhook_url' do

    it 'is webhook_url set at initialization' do
      expect(device.webhook_url).to eq('https://hooks.slack.com/services/test')
    end

    it 'raise an error if invalid' do
      options[:webhook_url] = 'foo'
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid Webhook URL: "foo"')
    end

    it 'can be an HTTP URL' do
      options[:webhook_url] = 'http://google.com'
      expect(device.webhook_url).to eq('http://google.com')
    end

    it 'can be an HTTPs URL' do
      options[:webhook_url] = 'https://google.com'
      expect(device.webhook_url).to eq('https://google.com')
    end

    it 'raise an error if not an HTTP(s) url' do
      options[:webhook_url] = 'ftp://google.com'
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid Webhook URL: "ftp://google.com"')
    end

    it 'can be set' do
      expect {
        device.webhook_url = 'http://google.com'
      }.to change { device.webhook_url }.from(options[:webhook_url]).to('http://google.com')
    end

  end

  describe '#write' do

    it 'sends a post to webhook URL with given given message and specified username' do
      expect(HTTParty).to receive(:post).with(options[:webhook_url], body: { 'text' => 'BAM!', 'username' => options[:username] }.to_json, headers: { 'Content-Type':  'application/json' }, timeout: 5)
      device.write('BAM!')
    end

    it 'returns nil' do
      allow(HTTParty).to receive(:post)
      expect(device.write('BAM!')).to be_nil
    end

    it 'does not send username if nil' do
      options.delete(:username)
      expect(HTTParty).to receive(:post).with(options[:webhook_url], body: { 'text' => 'BAM!' }.to_json, headers: { 'Content-Type':  'application/json' }, timeout: 5)
      device.write('BAM!')
    end

    it 'does nothing if log level is lower than specified one' do
      expect(HTTParty).not_to receive(:post)
      logger.debug('BIM!')
    end

    it 'send HTTP request if log level is equal to specified one' do
      expect(HTTParty).to receive(:post)
      logger.info('BIM!')
    end

    it 'send HTTP request if log level is higher to specified one' do
      expect(HTTParty).to receive(:post)
      logger.warn('BIM!')
    end

    it 'use specified timeout' do
      options[:timeout] = 12
      expect(HTTParty).to receive(:post).with(options[:webhook_url], body: { 'text' => 'BAM!', 'username' => options[:username] }.to_json, headers: { 'Content-Type':  'application/json' }, timeout: 12)
      device.write('BAM!')
    end

  end

end
