require 'spec_helper'

describe SlackLogDevice::Formatter do

  let(:max_message_length) { SlackLogDevice::Formatter::MAX_MESSAGE_LENGTH }

  describe '::MAX_MESSAGE_LENGTH' do

    it 'is 4000' do
      expect(SlackLogDevice::Formatter::MAX_MESSAGE_LENGTH).to be(4000)
    end

  end

  describe '#call' do

    context "with no block or metadata" do

      let(:formatter) { SlackLogDevice::Formatter.new }

      it 'returns a formatted message' do
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*: Hello World')
      end

      it 'message is stripped' do
        expect(formatter.call('DEBUG', Time.now, ' ', " \nHello World   ")).to eq('*`DEBUG`*: Hello World')
      end

      it 'message is converted to string' do
        expect(formatter.call('DEBUG', Time.now, ' ', 42)).to eq('*`DEBUG`*: 42')
      end

      it 'includes progname if given' do
        expect(formatter.call('DEBUG', Time.now, 'My App', 'Hello World')).to eq('*`DEBUG`* (*My App*): Hello World')
      end

      it 'formats exception' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['foo', 'bar'])
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred: BAM!\n\n```foo\nbar```")
      end

      it 'formats exception with no message' do
        exception = RuntimeError.new(' ')
        exception.set_backtrace(['foo', 'bar'])
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred:\n\n```foo\nbar```")
      end

      it 'formats exception with no backtrace' do
        exception = RuntimeError.new('BAM!')
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred: BAM!")
      end

      it 'strips exception message' do
        exception = RuntimeError.new("  BAM!   \n")
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred: BAM!")
      end

      it 'message never exceed 4000 chars (without exception)' do
        message = formatter.call('DEBUG', Time.now, nil, 'Bam' * (max_message_length / 2))
        expect(message.size).to eq(max_message_length)
        expect(message).to end_with('BamBa...')
      end

      it 'message never exceed 4000 chars (with exception)' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['a' * (max_message_length - 49)])
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message.size).to eq(max_message_length)
        expect(message).to end_with("aaaaaa...```")
      end

      it 'can be exactly 4000 chars with trace (without three dots)' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['a' * (max_message_length - 50)])
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message.size).to eq(max_message_length)
        expect(message).to end_with('a```')
      end

      it 'does not add three dots if less than 4000' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['a' * (max_message_length - 51)])
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message.size).to eq(max_message_length - 1)
        expect(message).to end_with('a```')
      end

      it 'does not format backtrace if message is too long' do
        exception = RuntimeError.new('BAM!' * max_message_length)
        exception.set_backtrace(['hello world'])
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message.size).to eq(max_message_length)
        expect(message).not_to include('hello')
        expect(message).not_to include('```')
      end

      it 'message does not exceed 4000 if there is no backtrace' do
        exception = RuntimeError.new('BAM!' * max_message_length)
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message.size).to eq(max_message_length)
      end

      it 'does not formats a blank backtrace (due to large message)' do
        exception = RuntimeError.new('a' * (max_message_length - 46))
        exception.set_backtrace(['hello world'])
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message.size).to eq(max_message_length - 8)
        expect(message).not_to include('```')
        expect(message).to end_with('a')
      end

      it 'can format a backtrace with just one char' do
        exception = RuntimeError.new('a' * (max_message_length - 47))
        exception.set_backtrace(['hello world'])
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message.size).to eq(max_message_length)
        expect(message).to end_with("aaa\n\n```h```")
      end

      it 'can format a backtrace with just one char and three dots' do
        exception = RuntimeError.new('a' * (max_message_length - 50))
        exception.set_backtrace(['hello world'])
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message.size).to eq(max_message_length)
        expect(message).to end_with("aaa\n\n```h...```")
      end

    end

    context 'if a block is given' do

      let(:formatter) { SlackLogDevice::Formatter.new { |message| "#{message.reverse} Hey hoy" } }

      it 'returns formatter message with block invoked' do
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq("*`DEBUG`*: dlroW olleH Hey hoy")
      end

      it 'invokes block with stripped message' do
        expect(formatter.call('DEBUG', Time.now, ' ', "    Hello World  \t")).to eq("*`DEBUG`*: dlroW olleH Hey hoy")
      end

      it 'does not append block message if blank' do
        formatter = SlackLogDevice.formatter { '   ' }
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*:')
      end

      it 'converts block value to string' do
        formatter = SlackLogDevice.formatter { 42 }
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*: 42')
      end

      it 'is correct if block returns nil' do
        formatter = SlackLogDevice.formatter { nil }
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*:')
      end

      it 'strips block return value' do
        formatter = SlackLogDevice.formatter { "  hey \n" }
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*: hey')
      end

      it 'includes progname if given' do
        expect(formatter.call('DEBUG', Time.now, 'MyApp', 'Hello World')).to eq("*`DEBUG`* (*MyApp*): dlroW olleH Hey hoy")
      end

      it 'formats exception' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['foo', 'bar'])
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred: !MAB Hey hoy\n\n```foo\nbar```")
      end

      it 'is correct with exception if block returns a blank message' do
        formatter = SlackLogDevice.formatter { '    ' }
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['foo', 'bar'])
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred:\n\n```foo\nbar```")
      end

      it 'message never exceed 4000 chars (without exception)' do
        message = formatter.call('DEBUG', Time.now, ' ', 'Hello World' * (max_message_length / 3))
        expect(message.size).to eq(max_message_length)
        expect(message).to end_with('olleHdlro...')
      end

      it 'message never exceed 4000 chars (with exception)' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['a' * max_message_length])
        message = formatter.call('DEBUG', Time.now, 'My App', exception)
        expect(message.size).to eq(max_message_length)
        expect(message).to end_with("aaaaaa...```")
      end

    end

    context 'with extra metadata' do

      let(:extra_metadata) {{
        'User ' => "   `#{user}` ",
        '  Reversed user' => -> (options) { user.reverse },
      }}
      let(:formatter) { SlackLogDevice::Formatter.new(extra_metadata: extra_metadata) }
      let(:user) { 'John' }

      it 'returns a message formatted' do
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq("*`DEBUG`*: Hello World\n\n• *User*: `John`\n• *Reversed user*: nhoJ")
      end

      it 'returns a message formatted (with exception)' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(['a', 'b'])
        message = formatter.call('DEBUG', Time.now, 'My App', exception)
        expect(message).to eq("*`DEBUG`* (*My App*): A `RuntimeError` occurred: BAM!\n\n• *User*: `John`\n• *Reversed user*: nhoJ\n\n```a\nb```")
      end

      it 'extra metadata are not added if message is too long' do
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World' * max_message_length)).not_to include('•')
      end

      it 'extra metadata are not added if message is too long (with exception)' do
        exception = RuntimeError.new('BAM!' * max_message_length)
        exception.set_backtrace(['a'])
        message = formatter.call('DEBUG', Time.now, 'My App', exception)
        expect(message).not_to include('•')
      end

      it 'blocks of extra metadata is invoked with options containing exception' do
        extra_metadata['Exception class'] = -> (options) { options[:exception].class.name }
        exception = RuntimeError.new('BAM!')
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to include('• *Exception class*: RuntimeError')
      end

      it 'blocks of extra metadata does not add exception option if not present' do
        extra_metadata['Exception?'] = -> (options) { options.key?(:exception) ? 'Yes' : 'No' }
        expect(formatter.call('DEBUG', Time.now, nil, 'Hello World')).to include("• *Exception?*: No")
      end

    end

    context 'with an exception with @__slack_log_device_request set' do

      let(:exception) { RuntimeError.new('BAM!').tap { |e| e.instance_variable_set(:@__slack_log_device_request, request) } }
      let(:formatter) { SlackLogDevice::Formatter.new }
      let(:request) { double(remote_addr: '127.0.0.1', user_agent: 'Mozilla', method: 'GET', url: 'http://google.com') }

      it 'logs metadata' do
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred: BAM!\n\n• *Method*: `GET`\n• *URL*: `http://google.com`\n• *Remote address*: `127.0.0.1`\n• *User-Agent*: `Mozilla`")
      end

    end

  end

  describe '#extra_metadata' do

    it 'is an empty hash by default' do
      expect(SlackLogDevice::Formatter.new.extra_metadata).to eq({})
    end

    it 'can be specified at constructor' do
      formatter = SlackLogDevice::Formatter.new(extra_metadata: { 'Bar' => 'foo' })
      expect(formatter.extra_metadata).to eq({ 'Bar' => 'foo' })
    end

  end

  describe '#initialize' do

    it 'raise an error if an invalid option is given' do
      expect {
        SlackLogDevice::Formatter.new(foo: 'bar')
      }.to raise_error(ArgumentError, 'Unknown key: :foo. Valid keys are: :extra_metadata')
    end

  end

end