
require "rails-pipeline/symmetric_encryptor"

module RailsPipeline

  module Subscriber

    Error = Class.new(StandardError)
    NoApiKeyError = Class.new(Error)
    WrongApiKeyError = Class.new(Error)

    class << self
      @@registered_models = {}
      @@registered_handlers = {}
      def register(payload_class, target_class, handler = nil)
        @@registered_models[payload_class] = target_class
        @@registered_handlers[payload_class] = handler
      end

      def target_class(payload_class)
        @@registered_models[payload_class]
      end

      def target_handler(payload_class)
        @@registered_handlers[payload_class]
      end
    end


    def self.included(base)
      RailsPipeline::SymmetricEncryptor.included(base)
      base.send :include, InstanceMethods
      base.extend ClassMethods
      if RailsPipeline::HAS_NEWRELIC
        base.send :include, ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
        base.extend  ::NewRelic::Agent::Instrumentation::ControllerInstrumentation::ClassMethods
        base.add_transaction_tracer :handle_envelope, category: :task
        base.add_transaction_tracer :handle_payload, category: :task
      end
    end

    module InstanceMethods

      # Take an EncryptedMessage envelope, and
      def handle_envelope(envelope)
        if ENV.has_key?("DISABLE_RAILS_PIPELINE") || ENV.has_key?("DISABLE_RAILS_PIPELINE_PROCESSING")
          RailsPipeline.logger.debug "Skipping incoming pipeline messages (disabled by env vars)"
          return
        end
        verify_api_key(envelope)
        payload_str = self.class.decrypt(envelope)
        begin
          clazz = Object.const_get(envelope.type_info)
        rescue NameError
          RailsPipeline.logger.info "Dropping unknown message #{envelope.type_info}"
          return
        end

        payload = clazz.parse(payload_str)
        handle_payload(payload, envelope)
      end

      def handle_payload(payload, envelope)
        version = _version(payload)
        clazz = target_class(payload)
        handler = target_handler(payload)
        event_type = envelope.event_type
        method = "from_pipeline_#{version}".to_sym

        if clazz.nil?
          # This message type is not registered for this app
          RailsPipeline.logger.info "Dropping unclaimed message #{payload.class.name}"
          return
        end

        if clazz.is_a?(Class)
          if handler
            # If a built in handler is registered, then just use it
            handler.new(payload, target_class: clazz, envelope: envelope).handle_payload
          elsif clazz.methods.include?(method)
            # Target class had a from_pipeline method, so just call it and move on
            target = clazz.send(method, payload, event_type)
          else
            RailsPipeline.logger.info "No handler set, dropping message #{payload.class.name}"
          end
          return target
        elsif clazz.is_a? Proc
          return clazz.call(payload)
        end
      end

      def verify_api_key(envelope)
        if envelope.api_key.present?
          if _api_keys.include?(envelope.api_key)
            return true
          else
            raise WrongApiKeyError.new
          end
        else
          raise NoApiKeyError.new
        end
      end

      def target_class(payload)
        RailsPipeline::Subscriber.target_class(payload.class)
      end

      def target_handler(payload)
        RailsPipeline::Subscriber.target_handler(payload.class)
      end

      def _version(payload)
        _, version = payload.class.name.split('_', 2)
        return version
      end

      def _api_keys
        return ENV.fetch('PIPELINE_API_KEYS', "").split(',')
      end

    end

    module ClassMethods
    end
  end
end
