require 'spec_helper'

describe SlackLogDevice::Formatter do

  let(:max_message_length) { SlackLogDevice::Formatter::MAX_MESSAGE_LENGTH }

  describe '::MAX_MESSAGE_LENGTH' do

    it 'is 4000' do
      expect(SlackLogDevice::Formatter::MAX_MESSAGE_LENGTH).to be(4000)
    end

  end

  describe '#call' do

    context 'with no options' do

      let(:formatter) { SlackLogDevice::Formatter.new }

      it 'returns formatted message with default metadata' do
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq("*`DEBUG`*: Hello World\n\n• *User*: `#{ENV['USER']}`\n• *Machine*: `#{Socket.gethostname}`\n• *PID*: `#{Process.pid}`")
      end

    end

    context 'with no block or metadata' do

      let(:formatter) { SlackLogDevice::Formatter.new(disable_default_metadata: true) }

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
        exception.set_backtrace(%w(foo bar))
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred: BAM!\n\n```foo\nbar```")
      end

      it 'formats exception with no message' do
        exception = RuntimeError.new(' ')
        exception.set_backtrace(%w(foo bar))
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred:\n\n```foo\nbar```")
      end

      it 'formats exception with no backtrace' do
        exception = RuntimeError.new('BAM!')
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq('*`DEBUG`*: A `RuntimeError` occurred: BAM!')
      end

      it 'strips exception message' do
        exception = RuntimeError.new("  BAM!   \n")
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq('*`DEBUG`*: A `RuntimeError` occurred: BAM!')
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
        expect(message).to end_with('aaaaaa...```')
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

      it 'formats exception cause' do
        exception = nil
        begin
          begin
            raise 'BIM!'
          rescue
            raise ArgumentError.new('BAM!')
          end
        rescue => e
          e.set_backtrace(['this is the backtrace'])
          exception = e
        end
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message).to include('*`DEBUG`*: A `ArgumentError` occurred: BAM!')
        expect(message).to include('```this is the backtrace```')
        expect(message).to include("\n\nCaused by `RuntimeError`: BIM!\n\n")
      end

      it 'backtrace is stripped' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(('1'..'50').to_a)
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message).to include('BAM!')
        expect(message).to include('9')
        expect(message).to end_with("\n10\n...```")
      end

      it 'message does not ends with more than three dots if backtrace is stripped' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(('1'..'9').to_a + ['a' * (max_message_length - 72)] + ['b'])
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message).to end_with("a\n...```")
        expect(message.size).to eq(max_message_length)
      end

    end

    context 'if a block is given' do

      let(:formatter) { SlackLogDevice::Formatter.new(disable_default_metadata: true) { |message| "#{message.reverse} Hey hoy" } }

      it 'returns formatter message with block invoked' do
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*: dlroW olleH Hey hoy')
      end

      it 'invokes block with stripped message' do
        expect(formatter.call('DEBUG', Time.now, ' ', "    Hello World  \t")).to eq('*`DEBUG`*: dlroW olleH Hey hoy')
      end

      it 'does not append block message if blank' do
        formatter = SlackLogDevice.formatter(disable_default_metadata: true) { '   ' }
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*:')
      end

      it 'converts block value to string' do
        formatter = SlackLogDevice.formatter(disable_default_metadata: true) { 42 }
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*: 42')
      end

      it 'is correct if block returns nil' do
        formatter = SlackLogDevice.formatter(disable_default_metadata: true) { nil }
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*:')
      end

      it 'strips block return value' do
        formatter = SlackLogDevice.formatter(disable_default_metadata: true) { "  hey \n" }
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq('*`DEBUG`*: hey')
      end

      it 'includes progname if given' do
        expect(formatter.call('DEBUG', Time.now, 'MyApp', 'Hello World')).to eq('*`DEBUG`* (*MyApp*): dlroW olleH Hey hoy')
      end

      it 'formats exception' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(%w(foo bar))
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred: !MAB Hey hoy\n\n```foo\nbar```")
      end

      it 'is correct with exception if block returns a blank message' do
        formatter = SlackLogDevice.formatter(disable_default_metadata: true) { '    ' }
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(%w(foo bar))
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
        expect(message).to end_with('aaaaaa...```')
      end

    end

    context 'with extra metadata' do

      let(:extra_metadata) {
        {
          'User ' => "   `#{user}` ",
          '  Reversed user' => -> (_options) { user.reverse },
        }
      }
      let(:formatter) { SlackLogDevice::Formatter.new(disable_default_metadata: true, extra_metadata:) }
      let(:user) { 'John' }

      it 'returns a message formatted' do
        expect(formatter.call('DEBUG', Time.now, ' ', 'Hello World')).to eq("*`DEBUG`*: Hello World\n\n• *User*: `John`\n• *Reversed user*: nhoJ")
      end

      it 'returns a message formatted (with exception)' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(%w(a b))
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
        expect(formatter.call('DEBUG', Time.now, nil, 'Hello World')).to include('• *Exception?*: No')
      end

    end

    context 'with request set in current thread' do

      let(:exception) { RuntimeError.new('BAM!') }
      let(:formatter) { SlackLogDevice::Formatter.new }
      let(:request) { double(remote_addr: '127.0.0.1', user_agent: 'Mozilla', method: 'GET', url: 'http://google.com') }

      before :each do
        Thread.current[:slack_log_device_request] = request
      end

      it 'logs metadata' do
        expect(formatter.call('DEBUG', Time.now, nil, exception)).to eq("*`DEBUG`*: A `RuntimeError` occurred: BAM!\n\n• *Method*: `GET`\n• *URL*: `http://google.com`\n• *Remote address*: `127.0.0.1`\n• *User-Agent*: `Mozilla`\n• *User*: `#{ENV['USER']}`\n• *Machine*: `#{Socket.gethostname}`\n• *PID*: `#{Process.pid}`")
      end

    end

    context 'with invalid encoding' do

      let(:exception) { RuntimeError.new('BâM!'.encode('cp1252')) }
      let(:formatter) { SlackLogDevice::Formatter.new(extra_metadata: { 'Baré'.encode('iso-8859-1') => 'foo' }) }
      let(:request) { double(remote_addr: '127.0.0.1', user_agent: 'Mozïlla'.encode('iso-8859-15'), method: 'GET', url: 'http://google.côm'.encode('iso-8859-1')) }

      before :each do
        Thread.current[:slack_log_device_request] = request
      end

      it 'is correct' do
        expect(formatter.call('DEBUG', Time.now, 'fôo'.encode('cp1252'), exception)).to eq("*`DEBUG`* (*fôo*): A `RuntimeError` occurred: BâM!\n\n• *Method*: `GET`\n• *URL*: `http://google.côm`\n• *Remote address*: `127.0.0.1`\n• *User-Agent*: `Mozïlla`\n• *User*: `#{ENV['USER']}`\n• *Machine*: `#{Socket.gethostname}`\n• *PID*: `#{Process.pid}`\n• *Baré*: foo")
      end

    end

    context 'with :max_backtrace_lines of 0' do

      let(:formatter) { SlackLogDevice::Formatter.new(disable_default_metadata: true, max_backtrace_lines: 0) }

      it 'backtrace is not printed' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(('1'..'50').to_a)
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message).to eq('*`DEBUG`*: A `RuntimeError` occurred: BAM!')
      end

    end

    context 'with :max_backtrace_lines of -1' do

      let(:formatter) { SlackLogDevice::Formatter.new(max_backtrace_lines: -1) }

      it 'backtrace is fully printed' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(('1'..'50').to_a)
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message).to include('BAM!')
        expect(message).to include("```1\n")
        expect(message).to end_with('50```')
      end

    end

    context 'with :max_backtrace_lines of 30' do

      let(:formatter) { SlackLogDevice::Formatter.new(max_backtrace_lines: 30) }

      it 'backtrace is correctly stripped' do
        exception = RuntimeError.new('BAM!')
        exception.set_backtrace(('1'..'50').to_a)
        message = formatter.call('DEBUG', Time.now, nil, exception)
        expect(message).to include('BAM!')
        expect(message).to end_with("\n30\n...```")
        expect(message).not_to include('31')
      end

    end
  end

  describe '#disable_default_metadata?' do

    it 'is false by default' do
      expect(SlackLogDevice::Formatter.new.disable_default_metadata?).to be(false)
    end

    it 'can be set to true' do
      expect(SlackLogDevice::Formatter.new(disable_default_metadata: true).disable_default_metadata?).to be(true)
    end

    it 'is false if blank' do
      expect(SlackLogDevice::Formatter.new(disable_default_metadata: ' ').disable_default_metadata?).to be(false)
      expect(SlackLogDevice::Formatter.new(disable_default_metadata: 1).disable_default_metadata?).to be(true)
    end

    it 'can be specified' do
      formatter = SlackLogDevice::Formatter.new
      expect {
        formatter.disable_default_metadata = true
      }.to change { formatter.disable_default_metadata? }.from(false).to(true)
    end

  end

  describe '#extra_metadata' do

    it 'is an empty hash by default' do
      expect(SlackLogDevice::Formatter.new.extra_metadata).to eq({})
    end

    it 'is an empty hash if nil' do
      formatter = SlackLogDevice::Formatter.new(extra_metadata: nil)
      expect(formatter.extra_metadata).to eq({})
    end

    it 'can be specified at constructor' do
      formatter = SlackLogDevice::Formatter.new(extra_metadata: { 'Bar' => 'foo' })
      expect(formatter.extra_metadata).to eq({ 'Bar' => 'foo' })
    end

    it 'can be specified at initialization' do
      formatter = SlackLogDevice::Formatter.new
      expect {
        formatter.extra_metadata = { 'Bar' => 'Foo' }
      }.to change { formatter.extra_metadata }.from({}).to({ 'Bar' => 'Foo' })
    end

  end

  describe '#icon_emoji' do

    let(:formatter) { SlackLogDevice::Formatter.new }

    it 'returns emoji (or nil) for given level' do
      formatter.icon_emojis = { 'INFO' => ':test:' }
      expect(formatter.icon_emoji('info')).to eq(':test:')
      expect(formatter.icon_emoji(:debug)).to eq(':bug:')
      expect(formatter.icon_emoji('FATAL ')).to eq(':fire:')
    end

    it 'raise an error if level is invalid' do
      expect {
        formatter.icon_emoji('BUG')
      }.to raise_error('Invalid log severity: "BUG"')
    end

  end

  describe '#icon_emoji=' do

    let(:formatter) { SlackLogDevice::Formatter.new }

    it 'set emoji for all severities' do
      formatter.icon_emoji = ':bug:'
      expect(formatter.icon_emoji('warn       ')).to eq(':bug:')
      expect(formatter.icon_emoji('FATAL')).to eq(':bug:')
    end

    it 'can be removed for all severities' do
      formatter.icon_emoji = "  \n "
      expect(formatter.icon_emoji('warn')).to be(nil)
      expect(formatter.icon_emoji('FATAL')).to be(nil)
    end

    it 'can also be used at constructor level' do
      formatter = SlackLogDevice::Formatter.new(icon_emoji: ':skull:')
      expect(formatter.icon_emojis).to include('FATAL' => ':skull:', 'DEBUG' => ':skull:')
    end

  end

  describe '#icon_emojis' do

    it 'has default values if not specified' do
      formatter = SlackLogDevice::Formatter.new
      expect(formatter.icon_emojis).to include('DEBUG' => ':bug:', 'FATAL' => ':fire:')
    end

    it 'some values can be set' do
      formatter = SlackLogDevice::Formatter.new(icon_emojis: { 'DEBUG' => ':test:' })
      expect(formatter.icon_emojis).to include('DEBUG' => ':test:', 'FATAL' => ':fire:')
    end

    it 'raise an error if key is invalid' do
      expect {
        SlackLogDevice::Formatter.new(icon_emojis: { 'BUG' => ':test:' })
      }.to raise_error('Invalid log severity: "BUG"')
    end

    it 'removes default value if blank' do
      formatter = SlackLogDevice::Formatter.new(icon_emojis: { 'INFO' => '  ' })
      expect(formatter.icon_emojis).to include('INFO' => nil, 'FATAL' => ':fire:')
    end

    it 'keys are case insensitive and can be specified as symbol' do
      formatter = SlackLogDevice::Formatter.new(icon_emojis: { DebUg: ':test:' })
      expect(formatter.icon_emojis).to include('DEBUG' => ':test:', 'FATAL' => ':fire:')
    end

    it 'can be set via setter' do
      formatter = SlackLogDevice::Formatter.new
      formatter.icon_emojis = { 'DEBUG' => ':test' }
      expect(formatter.icon_emojis).to include('DEBUG' => ':test', 'FATAL' => ':fire:')
    end

    it 'is frozen' do
      formatter = SlackLogDevice::Formatter.new(icon_emojis: { DebUg: ':test:' })
      expect {
        formatter.icon_emojis['WARN'] = ':test:'
      }.to raise_error(FrozenError)
    end

  end

  describe '#initialize' do

    it 'raise an error if an invalid option is given' do
      expect {
        SlackLogDevice::Formatter.new(foo: 'bar')
      }.to raise_error(ArgumentError, 'Unknown key: :foo. Valid keys are: :disable_default_metadata, :extra_metadata, :icon_emoji, :icon_emojis, :max_backtrace_lines')
    end

  end

  describe '#max_backtrace_lines' do

    it 'is 10 by default' do
      expect(SlackLogDevice::Formatter.new.max_backtrace_lines).to be(10)
    end

    it 'can be specified at constructor' do
      formatter = SlackLogDevice::Formatter.new(max_backtrace_lines: 50)
      expect(formatter.max_backtrace_lines).to be(50)
    end

    it 'can be -1' do
      formatter = SlackLogDevice::Formatter.new(max_backtrace_lines: -1)
      expect(formatter.max_backtrace_lines).to be(-1)
    end

    it 'can be set as string' do
      formatter = SlackLogDevice::Formatter.new(max_backtrace_lines: '42')
      expect(formatter.max_backtrace_lines).to be(42)
    end

    it 'raise an error if < -1' do
      expect {
        SlackLogDevice::Formatter.new(max_backtrace_lines: -2)
      }.to raise_error(ArgumentError, 'Invalid max backtrace lines: -2')
    end

    it 'raise an error if invalid' do
      expect {
        SlackLogDevice::Formatter.new(max_backtrace_lines: 'foo')
      }.to raise_error(ArgumentError, 'Invalid max backtrace lines: "foo"')
    end

    it 'can be set via setter' do
      formatter = SlackLogDevice::Formatter.new
      expect {
        formatter.max_backtrace_lines = 15
      }.to change { formatter.max_backtrace_lines }.from(10).to(15)
    end

  end

end
