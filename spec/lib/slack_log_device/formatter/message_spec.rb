require 'spec_helper'

describe SlackLogDevice::Formatter::Message do

  let(:message) { SlackLogDevice::Formatter::Message.new('test') }

  it 'is a string' do
    expect(message).to be_a(String)
    expect(message).to eq('test')
  end

  describe '#icon_emoji' do

    it 'can be set at constructor level' do
      message = SlackLogDevice::Formatter::Message.new('test', icon_emoji: ':+1:')
      expect(message.icon_emoji).to eq(':+1:')
    end

    it 'is nil by default' do
      expect(message.icon_emoji).to be(nil)
    end

    it 'is stripped' do
      expect {
        message.icon_emoji = ' :+1:  '
      }.to change { message.icon_emoji }.from(nil).to(':+1:')
    end

    it 'is nil if blank' do
      message.icon_emoji = ':fire:'
      expect {
        message.icon_emoji = '   '
      }.to change { message.icon_emoji }.from(':fire:').to(nil)
    end

  end

end
