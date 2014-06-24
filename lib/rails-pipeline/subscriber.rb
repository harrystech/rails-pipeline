
require "rails-pipeline/symmetric_encryptor"

module RailsPipeline
  module Subscriber
    class << self
      @@registered_models = {}
      def register(payload_class, target_class)
        @@registered_models[payload_class] = target_class

        # TODO allow registering procs
      end

      def target_class(payload_class)
        @@registered_models[payload_class]
      end
    end


    def self.included(base)
      RailsPipeline::SymmetricEncryptor.included(base)
      base.send :include, InstanceMethods
      base.extend ClassMethods
    end

    module InstanceMethods

      # Take an EncryptedMessage envelope, and 
      def handle_envelope(envelope)
        if ENV.has_key?("DISABLE_RAILS_PIPELINE") || ENV.has_key?("DISABLE_RAILS_PIPELINE_PROCESSING")
          RailsPipeline.logger.debug "Skipping incoming pipeline messages (disabled by env vars)"
          return
        end
        payload_str = self.class.decrypt(envelope)
        begin
          clazz = Object.const_get(envelope.type_info)
        rescue NameError
          RailsPipeline.logger.info "Dropping unknown message #{envelope.type_info}"
          return
        end

        payload = clazz.parse(payload_str)
        handle_payload(payload)

      end

      def handle_payload(payload)
        version = _version(payload)
        clazz = target_class(payload)
        method = "from_pipeline_#{version}".to_sym

        if clazz.nil?
          # This message type is not registered for this app
          RailsPipeline.logger.info "Dropping unclaimed message #{payload.class.name}"
          return
        end

        if clazz.is_a?(Class) && clazz.methods.include?(method)
          target = clazz.send(method, payload)
          # TODO can we just save this now?
          target.save!
          return target
        elsif clazz.is_a? Proc
          return clazz.call(payload)
        end
      end

      def target_class(payload)
        RailsPipeline::Subscriber.target_class(payload.class)
      end

      def _version(payload)
        _, version = payload.class.name.split('_', 2)
        return version
      end

    end

    module ClassMethods
    end
  end
end
