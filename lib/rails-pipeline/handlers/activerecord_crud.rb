module RailsPipeline
    module SubscriberHandler
        class ActiveRecordCRUD < BaseHandler
            def handle_payload
                case event_type
                when RailsPipeline::EncryptedMessage::EventType::CREATED
                    object = target_class.where({id: payload.id}).first
                    if object.nil?
                        ActiveRecord::Base.transaction do
                            object = target_class.create!(_attributes(payload), without_protection: true)
                        end
                    end
                    object
                when RailsPipeline::EncryptedMessage::EventType::UPDATED
                    object = target_class.where({id: payload.id}).first

                    if object.nil?
                        ActiveRecord::Base.transaction do
                            object = target_class.create!(_attributes(payload), without_protection: true)
                        end
                    elsif object && (payload.updated_at.to_i >= object.updated_at.to_i)
                        ActiveRecord::Base.transaction do
                            object.update_attributes!(_attributes(payload), without_protection: true)
                        end
                    end

                    object
                when RailsPipeline::EncryptedMessage::EventType::DELETED
                    object = target_class.find(payload.id)
                    ActiveRecord::Base.transaction do
                        object.destroy
                    end
                    object
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
