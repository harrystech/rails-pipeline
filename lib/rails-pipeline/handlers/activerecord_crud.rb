module RailsPipeline
  module SubscriberHandler
    class ActiveRecordCRUD < BaseHandler
      def handle_payload
        begin
          case event_type
          when RailsPipeline::EncryptedMessage::EventType::CREATED
            return target_class.create!(_attributes(payload), without_protection: true)
          when RailsPipeline::EncryptedMessage::EventType::UPDATED
            object = target_class.where({id: payload.id}).first_or_create!
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

        puts "teh attributes"
        puts attributes_hash.inspect
        puts "teh attributes"


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
