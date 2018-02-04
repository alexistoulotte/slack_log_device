class SlackLogDevice

  class Formatter

    class Message < String

      attr_reader :icon_emoji

      def initialize(text, icon_emoji: nil)
        super(text)
        self.icon_emoji = icon_emoji
      end

      def icon_emoji=(value)
        @icon_emoji = value.presence.try(&:strip)
      end

    end

  end

end
