require "rails-pipeline/symmetric_encryptor"

module RailsPipeline
    class BasicEmitter
        include RailsPipeline::SymmetricEncryptor

        def self.emit(topic, type_info, payload, version, event_type, publisher)
            if ENV.has_key?("DISABLE_RAILS_PIPELINE") || ENV.has_key?("DISABLE_RAILS_PIPELINE_EMISSION")
                RailsPipeline.logger.debug "Skipping outgoing pipeline messages (disabled by env vars)"
                return
            end

            begin
                enc_data = create_message(topic,
                                          type_info,
                                          payload,
                                          version,
                                          RailsPipeline::EncryptedMessage::EventType::CREATED)

                publisher.publish(enc_data.topic, enc_data.to_s)
            rescue Exception => e
                RailsPipeline.logger.error("Error during emit(): #{e}")
                puts e.backtrace.join("\n")
                raise e
            end
        end

        def self.create_message(topic, type_info, payload, version, event_type)
            RailsPipeline.logger.debug "Emitting to #{topic}"
            self.encrypt(payload,
                               type_info: type_info,
                               topic: topic,
                               event_type: event_type)
        end

    end

end
