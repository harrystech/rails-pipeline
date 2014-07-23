module RailsPipeline
  module SubscriberHandler
    class BaseHandler
      attr_reader :payload, :event_type, :target_class, :envelope

      def initialize(payload, target_class: nil, envelope: nil, event_type: nil)
        @payload = payload
        @target_class = target_class
        @envelope = envelope
        if envelope
          @event_type = envelope.event_type
        else
          @event_type = event_type
        end
      end

    end
  end
end
