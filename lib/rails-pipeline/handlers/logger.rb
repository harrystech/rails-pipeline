module RailsPipeline
  module SubscriberHandler
    class Logger < BaseHandler
      def handle_payload
        # We'll need to GPG encrypt this
        # Maybe it should encrypt using a public key set in environment variable
        # Then the subscriber app would set it when installing the pipeline
        # Would need to add configuration for that
        RailsPipeline.logger.info envelope.to_s
      end
    end
  end
end
