module RailsPipeline
  module SubscriberHandler
    class ActiveRecordCRUD
      attr_reader :payload, :event_type, :target_class

      def initialize(payload, target_class, event_type)
        @payload = payload
        @target_class = target_class
        @event_type = event_type
      end

      def handle_payload
        begin
          case event_type
          when RailsPipeline::EncryptedMessage::EventType::CREATED
            return target_class.create!(_attributes(payload), without_protection: true)
          when RailsPipeline::EncryptedMessage::EventType::UPDATED
            # We might want to allow confiugration of the primary key field
            object = target_class.find(payload.id)
            object.update_attributes!(_attributes(payload), without_protection: true)
            return object
          when RailsPipeline::EncryptedMessage::EventType::DELETED
            object = target_class.find(payload.id)
            object.destroy
            return object
          end
        rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound => e
          RailsPipeline.logger.error "Could not handle payload: #{payload.inspect}, event_type: #{event_type}"
        end
      end

      def _attributes(payload)
        attributes_hash = payload.to_hash
        attributes_hash.each do |attribute_name, value|
          if attribute_name.match /_at$/
            attributes_hash[attribute_name] = Time.at(value).to_datetime
          end
        end
        return attributes_hash
      end
    end
  end
end
