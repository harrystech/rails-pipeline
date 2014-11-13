require "rails-pipeline/symmetric_encryptor"

module RailsPipeline
    class BasicEmitter
        include RailsPipeline::SymmetricEncryptor

        # @param [Hash] params Message fields for message generation
        # @option params [String] :topic
        # @option params [String] :type_info
        # @option params [String] :payload
        # @option params [String] :version
        # @option params [Integer] :event_type
        # @param [Publisher] An object that responds to publish
        def self.emit(params, publisher)
            if ENV.has_key?("DISABLE_RAILS_PIPELINE") || ENV.has_key?("DISABLE_RAILS_PIPELINE_EMISSION")
                RailsPipeline.logger.debug "Skipping outgoing pipeline messages (disabled by env vars)"
                return
            end

            begin
                enc_data = create_message(params)
                publisher.publish(enc_data.topic, enc_data.to_s)
            rescue Exception => e
                RailsPipeline.logger.error("Error during emit(): #{e}")
                puts e.backtrace.join("\n")
                raise e
            end
        end



        # Created an encryped message with the provided payload data and associated
        # metadata.
        #
        # @param [Hash] params Message fields for message generation
        # @option params [String] :topic
        # @option params [String] :type_info
        # @option params [String] :payload
        # @option params [String] :version
        # @option params [Integer] :event_type
        def self.create_message(params)
            RailsPipeline.logger.debug "Emitting to #{params[:topic]}"
            self.encrypt(params[:payload],
                         type_info: params[:type_info],
                         topic: params[:topic],
                         event_type: params[:event_type])
        end

    end

end
