# A Pipeline emitter is an active record model that, when changed,
# will publish the changed fields to some sort of queue

require "rails-pipeline/symmetric_encryptor"

module RailsPipeline
  module Emitter

    def self.included(base)
      RailsPipeline::SymmetricEncryptor.included(base)
      base.send :include, InstanceMethods
      base.extend ClassMethods
      base.after_commit :emit_on_create, on: :create, if: :persisted?
      base.after_commit :emit_on_update, on: :update
      base.after_commit :emit_on_destroy, on: :destroy

      if RailsPipeline::HAS_NEWRELIC
        base.send :include, ::NewRelic::Agent::MethodTracer
        base.add_method_tracer :emit, 'Pipeline/Emitter/emit'
      end
    end

    module InstanceMethods
      def emit_on_create
        emit(RailsPipeline::EncryptedMessage::EventType::CREATED)
      end

      def emit_on_update
        emit(RailsPipeline::EncryptedMessage::EventType::UPDATED)
      end

      def emit_on_destroy
        emit(RailsPipeline::EncryptedMessage::EventType::DELETED)
      end

      def emit(event_type = RailsPipeline::EncryptedMessage::EventType::CREATED)
        if ENV.has_key?("DISABLE_RAILS_PIPELINE") || ENV.has_key?("DISABLE_RAILS_PIPELINE_EMISSION")
          RailsPipeline.logger.debug "Skipping outgoing pipeline messages (disabled by env vars)"
          return
        end
        begin
          self.class.pipeline_versions.each do |version|
            enc_data = create_message(version, event_type)
            self.publish(enc_data.topic, enc_data.to_s)
          end
        rescue Exception => e
          RailsPipeline.logger.error("Error during emit(): #{e}")
          puts e.backtrace.join("\n")
          raise e
        end
      end

      def create_message(version, event_type)
        topic = self.class.topic_name(version)
        RailsPipeline.logger.debug "Emitting to #{topic}"
        data = self.send("to_pipeline_#{version}")
        enc_data = self.class.encrypt(data.to_s, type_info: data.class.name, topic: topic, event_type: event_type)
        return enc_data
      end

    end

    module ClassMethods
      # Get the list of versions to emit (all that are implemented, basically)
      def pipeline_versions
        if pipeline_method_cache.any?
          return pipeline_method_cache.keys
        end
        versions = []
        pipeline_methods = instance_methods.grep(/^to_pipeline/).sort
        pipeline_methods.each do |pipeline_method|
          version = pipeline_method.to_s.gsub("to_pipeline_", "")
          if version.starts_with?("1_") && version != "1_0"
            # Delete the default v1.0 emitter if a later v1 emitter is defined
            i = versions.index("1_0")
            versions.delete_at(i) if !i.nil?
          end
          pipeline_method_cache[version] = pipeline_method
          versions << version
        end
        return versions
      end

      # Get pub/sub topic name to which changes to this model will be published
      def topic_name(version="1_0")
        return "harrys-#{Rails.env}-v#{major(version)}-#{table_name}"
      end

      # Get the major version number from a "1_1" style major/minor version string
      def major(version)
        if version.include? '_'
          major, _ = version.split('_', 2)
        else
          major = version
        end
        return major
      end

      def _secret
        ENV.fetch("PIPELINE_SECRET", Rails.application.config.secret_token)
      end

      def pipeline_method_cache
        @pipeline_method_cache ||= {}
      end

      def pipeline_method_cache=(cache)
        @pipeline_method_cache = cache
      end

    end
  end


  module RedisEmitter
    def self.included(base)
      RailsPipeline::Emitter.included(base)
      RailsPipeline::RedisPublisher.included(base)
    end
  end
end
