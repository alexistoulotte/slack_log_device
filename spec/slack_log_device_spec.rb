require 'spec_helper'

describe SlackLogDevice do

  let(:device) { SlackLogDevice.new(options) }
  let(:options) { { username: 'MyApp', webhook_url: 'https://hooks.slack.com/services/test' } }

  before :each do
    allow(HTTParty).to receive(:post)
  end

  it 'is not a LogDevice instance' do
    expect(device).not_to be_a(Logger::LogDevice)
  end

  describe '::FORMATTER' do

    let(:formatter) { SlackLogDevice::FORMATTER }

    it 'returns a proc' do
      expect(formatter).to be_a(Proc)
    end

    describe '#call' do

      it 'returns a formatted message' do
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*: Hello World')
      end

      it 'includes progname if given' do
        expect(formatter.call('DEBUG', Time.now, 'My App', 'Hello World')).to eq('*`DEBUG`* (*My App*): Hello World')
      end

      it 'formats exception' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['foo', 'bar'])
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred: BAM!\n\n```foo\nbar```")
      end

      it 'message with trace never exceed 4000 chars' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['a' * 4500])
        message = formatter.call('DEBUG', Time.now, 'My App', exception)
        expect(message.size).to eq(4000)
        expect(message).to end_with("aaaaaa...```")
      end

      it 'can be exactly 4000 chars (without three dots)' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['a' * 3950])
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message).to end_with('a```')
        expect(message.size).to eq(4000)
      end

    end

  end

  describe '#auto_flush?' do

    it 'is false by default' do
      options.delete(:auto_flush)
      expect(device).not_to be_auto_flush
    end

    it 'can be set to true' do
      options[:auto_flush] = true
      expect(device).to be_auto_flush
    end

  end

  describe '#close' do

    it 'does nothing' do
      expect {
        device.close
      }.not_to raise_error
    end

  end

  describe '#channel' do

    it 'is null by default' do
      options.delete(:channel)
      expect(device.channel).to be_nil
    end

    it 'is nil if blank' do
      options[:channel] = "  \n"
      expect(device.channel).to be_nil
    end

    it 'can be set' do
      expect {
        device.channel = '#foo-bar_42abc'
      }.to change { device.channel  }.from(nil).to('#foo-bar_42abc')
    end

    it 'raise an error if it contains spaces' do
      expect {
        device.channel = '#foo bar'
      }.to raise_error(ArgumentError, 'Invalid channel specified: "#foo bar", it must start with # or @ and be in lower case with no spaces or special chars and its length must not exceed 22 chars')
    end

    it 'raise an error if it contains more than 22 chars (including #)' do
      expect {
        device.channel = "##{'a' * 22}"
      }.to raise_error(ArgumentError)
      device.channel = "##{'a' * 21}" # ok
    end

    it 'raise an error if it contains upper case letters' do
      expect {
        device.channel = '#Foo'
      }.to raise_error(ArgumentError)
    end

    it 'raise an error if it contains special chars' do
      expect {
        device.channel = '#f{oo'
      }.to raise_error(ArgumentError)
    end

    it 'raise an error if it does not start with a # or @' do
      expect {
        device.channel = 'foo'
      }.to raise_error(ArgumentError)
      device.channel = '#foo' # ok
      device.channel = '@foo' # ok
    end

    it 'raise an error if it only contains prefix' do
      expect {
        device.channel = '#'
      }.to raise_error(ArgumentError)
    end

  end

  describe '#flush' do

    it 'sends a post to webhook URL with given given message and specified username' do
      device.write('BAM!')
      expect(HTTParty).to receive(:post).with(options[:webhook_url], body: { 'text' => 'BAM!', 'username' => options[:username] }.to_json, headers: { 'Content-Type':  'application/json' }, timeout: 5)
      device.flush
    end

    it 'does not send username if nil' do
      options.delete(:username)
      device.write('BAM!')
      expect(HTTParty).to receive(:post).with(options[:webhook_url], body: { 'text' => 'BAM!' }.to_json, headers: { 'Content-Type':  'application/json' }, timeout: 5)
      device.flush
    end

    it 'use specified channel' do
      options[:channel] = '#foo'
      device.write('BAM!')
      expect(HTTParty).to receive(:post).with(options[:webhook_url], body: { 'text' => 'BAM!', 'channel': '#foo', 'username' => options[:username] }.to_json, headers: { 'Content-Type':  'application/json' }, timeout: 5)
      device.flush
    end

    it 'use specified timeout' do
      options[:timeout] = 12
      device.write('BAM!')
      expect(HTTParty).to receive(:post).with(options[:webhook_url], body: { 'text' => 'BAM!', 'username' => options[:username] }.to_json, headers: { 'Content-Type':  'application/json' }, timeout: 12)
      device.flush
    end

    it 'flushes all message writen separated by a new line' do
      device.write('BAM!')
      device.write('BIM!')
      expect(HTTParty).to receive(:post).with(options[:webhook_url], body: { 'text' => "BAM!\nBIM!", 'username' => options[:username] }.to_json, headers: { 'Content-Type':  'application/json' }, timeout: 5)
      device.flush
    end

    it 'returns nil' do
      device.write('BIM!')
      expect(device.flush).to be_nil
    end

    it 'clears buffer' do
      device.write('BAM!')
      device.write('BIM!')
      expect {
        device.flush
      }.to change { device.instance_variable_get(:@buffer) }.to([])
      expect(HTTParty).not_to receive(:post)
      device.flush
    end

  end

  describe '#flush?' do

    it 'is true if max_buffer_size is reached' do
      options[:max_buffer_size] = 10
      device.write('012345678')
      expect {
        device.instance_variable_get(:@buffer).push('a')
      }.to change { device.flush? }.from(false).to(true)
    end

    it 'use byte size to compare max_buffer_size' do
      options[:max_buffer_size] = 10
      device.write('0123456é')
      expect {
        device.instance_variable_get(:@buffer).push('a')
      }.to change { device.flush? }.from(false).to(true)
    end

    it 'is true if auto_flush option is present' do
      expect {
        device.auto_flush = true
      }.to change { device.flush? }.from(false).to(true)
    end

    it 'is true if flush delay is 0' do
      expect {
        device.flush_delay = 0
      }.to change { device.flush? }.from(false).to(true)
    end

  end

  describe '#flush_delay' do

    it 'is 1 by default' do
      expect(device.flush_delay).to eq(1)
    end

    it 'can be specified' do
      options[:flush_delay] = 10
      expect(device.flush_delay).to be(10)
    end

    it 'raise an error if invalid' do
      options[:flush_delay] = 'foo'
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid flush delay: "foo"')
    end

    it 'raise an error if negative' do
      options[:flush_delay] = -1
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid flush delay: -1')
    end

    it 'can be zero' do
      options[:flush_delay] = 0
      expect(device.flush_delay).to be(0)
    end

    it 'raise an error if blank' do
      options[:flush_delay] = ' '
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid flush delay: " "')
    end

    it 'raise an error if set as nil' do
      expect {
        device.flush_delay = nil
      }.to raise_error(ArgumentError, 'Invalid flush delay: nil')
    end

    it 'can be specified as string' do
      options[:flush_delay] = '42'
      expect(device.flush_delay).to eq(42)
    end

    it 'can be set' do
      expect {
        device.flush_delay = 15
      }.to change { device.flush_delay }.from(1).to(15)
    end

  end

  describe '#initialize' do

    it 'raise an error if an invalid option is given' do
      expect {
        SlackLogDevice.new(foo: 'bar')
      }.to raise_error(ArgumentError, "Unknown key: :foo. Valid keys are: :auto_flush, :channel, :flush_delay, :max_buffer_size, :timeout, :username, :webhook_url")
    end

    it 'raise an error if webhook option is not given' do
      expect {
        SlackLogDevice.new(options.except(:webhook_url))
      }.to raise_error(ArgumentError, 'Webhook URL must be specified')
    end

  end

  describe '#max_buffer_size' do

    it 'is 128 kilobytes by default' do
      expect(device.max_buffer_size).to eq(1024 * 128)
    end

    it 'can be specified' do
      options[:max_buffer_size] = 42
      expect(device.max_buffer_size).to be(42)
    end

    it 'raise an error if invalid' do
      options[:max_buffer_size] = 'foo'
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid max buffer size: "foo"')
    end

    it 'raise an error if negative' do
      options[:max_buffer_size] = -1
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid max buffer size: -1')
    end

    it 'can be zero' do
      options[:max_buffer_size] = 0
      expect(device.max_buffer_size).to be_zero
    end

    it 'raise an error if blank' do
      options[:max_buffer_size] = ' '
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid max buffer size: " "')
    end

    it 'raise an error if set as nil' do
      expect {
        device.max_buffer_size = nil
      }.to raise_error(ArgumentError, 'Invalid max buffer size: nil')
    end

    it 'can be specified as string' do
      options[:max_buffer_size] = '42'
      expect(device.max_buffer_size).to eq(42)
    end

    it 'can be set' do
      expect {
        device.max_buffer_size = 1024
      }.to change { device.max_buffer_size }.from(1024 * 128).to(1024)
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

    it 'raise an error if negative' do
      options[:timeout] = -1
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid timeout: -1')
    end

    it 'raise an error if zero' do
      options[:timeout] = 0
      expect {
        device
      }.to raise_error(ArgumentError, 'Invalid timeout: 0')
    end

    it 'raise an error if blank' do
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
      }.to raise_error(ArgumentError, 'Invalid webhook URL: "foo"')
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
      }.to raise_error(ArgumentError, 'Invalid webhook URL: "ftp://google.com"')
    end

    it 'can be set' do
      expect {
        device.webhook_url = 'http://google.com'
      }.to change { device.webhook_url }.from(options[:webhook_url]).to('http://google.com')
    end

  end

  describe '#write' do

    it 'returns nil' do
      expect(device.write('BAM!')).to be_nil
    end

    it 'strips message' do
      device.write("     BAM  !\n")
      expect(device.instance_variable_get(:@buffer)).to eq(['BAM  !'])
    end

    it 'converts message to string' do
      device.write(42)
      expect(device.instance_variable_get(:@buffer)).to eq(['42'])
    end

    it 'does nothing if message is blank' do
      expect(HTTParty).not_to receive(:post)
      expect {
        expect(device.write(" \n")).to be_nil
      }.not_to change { device.instance_variable_get(:@buffer) }
    end

    it 'does nothing if message is nil' do
      expect(HTTParty).not_to receive(:post)
      expect(device.write(nil)).to be_nil
      expect(device.instance_variable_get(:@buffer)).to eq([])
    end

    it 'does not post HTTP message if auto flush is false' do
      expect(HTTParty).not_to receive(:post)
      device.write('BAM!')
    end

  end

  describe Logger, 'with slack log device' do

    let(:logger) { Logger.new(device).tap { |logger| logger.level = Logger::INFO } }

    it 'does nothing if log level is lower than specified one' do
      expect(HTTParty).not_to receive(:post)
      logger.debug('BIM!')
      device.flush
    end

    it 'send HTTP request if log level is equal to specified one' do
      expect(HTTParty).to receive(:post)
      logger.info('BIM!')
      device.flush
    end

    it 'send HTTP request if log level is higher to specified one' do
      expect(HTTParty).to receive(:post)
      logger.warn('BIM!')
      device.flush
    end

    describe '#close' do

      it 'does not raise any error' do
        expect {
          logger.close
        }.not_to raise_error
      end

    end

    describe '#reopen' do

      it 'does not raise any error' do
        expect {
          logger.reopen
        }.not_to raise_error
      end

    end

    describe '@logdev' do

      let(:logdev) { logger.instance_variable_get(:@logdev) }

      it 'is a LogDevice instance' do
        expect(logdev).to be_a(Logger::LogDevice)
      end

      describe '#dev' do

        let(:dev) { logdev.dev }

        it 'is SlackLogDevice instance' do
          expect(dev).to be(device)
        end

      end

      describe '#filename' do

        it 'is nil' do
          expect(logdev.filename).to be_nil
        end

      end

    end

  end

end
