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

      def registered_handlers
        @@registered_handlers
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

      # Take an EncryptedMessage envelope, and decrypt the cipher text, then
      # get the protobuf object out of it
      def handle_envelope(envelope)
        if ENV.has_key?("DISABLE_RAILS_PIPELINE") || ENV.has_key?("DISABLE_RAILS_PIPELINE_PROCESSING")
          RailsPipeline.logger.debug "Skipping incoming pipeline messages (disabled by env vars)"
          return
        end
        verify_api_key(envelope)
        payload_str = self.class.decrypt(envelope)

        # Find the registered minor version & its related handler to parse and
        # process this message.
        clazz = registered_class_on_same_major_version(envelope.type_info)

        if clazz.nil?
          # No compatible version of this message is registered for this app.
          RailsPipeline.logger.info "Dropping unclaimed message #{envelope.type_info} (no compatible version registered)."
          return
        end

        # Parse and handle the payload.
        payload = clazz.parse(payload_str)
        handle_payload(payload, envelope)
      end

      # Take a protobuf object (payload) and forward it to the appropriate
      # handler/method/proc
      def handle_payload(payload, envelope)
        version = _version(payload)
        clazz = target_class(payload)
        handler_class = target_handler(payload)
        event_type = envelope.event_type
        method = most_suitable_handler_method_name(version, clazz)

        if clazz.is_a?(Class)
          if handler_class
            # If a built in handler_class is registered, then just use it
            handler_class.new(payload, target_class: clazz, envelope: envelope).handle_payload
          elsif method
            # Target class had a from_pipeline method, so just call it and move on
            target = clazz.send(method, payload, event_type)
          else
            RailsPipeline.logger.info "No handler set, dropping message #{payload.class.name}"
          end
          return target
        elsif clazz.is_a?(Proc)
          return clazz.call(payload)
        end
      end

      def registered_class_on_same_major_version(payload_class_name)
        if Subscriber.registered_handlers.has_key?(payload_class_name)
          # The version we've been given has been registered. Return that.
          return Object.const_get(payload_class_name)
        end

        # Lops off the minor version from the payload class name so
        # we can find the registered message type with the same major version.
        class_name_with_major_version =
          payload_class_name
          .split("_", 3)[0, 2]
          .join("_")

        # Look for message types with the same major version.
        available_classes = Subscriber.registered_handlers
          .keys
          .map(&:to_s)
          .select { |class_name| class_name.start_with?(class_name_with_major_version) }

        if available_classes.empty?
          # No message types with the same major version.
          return nil
        else
          # There's a message type with the same major version.
          return Object.const_get(available_classes.first)
        end
      end

      def most_suitable_handler_method_name(version, receiver_class)
        # Returns the closest lower implemented method in target_class for the given version
        cached_method = self.class.handler_method_cache[version]
        if cached_method
          return cached_method
        end
        available_methods = receiver_class.methods.grep(%r{^from_pipeline_#{version.major}})
          .reject { |method_name| method_name.to_s.split('_').last.to_i > version.minor }
          .sort
          .reverse

        # cache handler method for this version
        self.class.handler_method_cache[version] = available_methods.first
        return available_methods.first
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
        return RailsPipeline::PipelineVersion.new(version)
      end

      def _api_keys
        return ENV.fetch('PIPELINE_API_KEYS', "").split(',')
      end

    end

    module ClassMethods

      def handler_method_cache
        @handler_method_cache ||= {}
      end

      def handler_method_cache=(cache)
        @handler_method_cache = cache
      end
    end
  end
end
