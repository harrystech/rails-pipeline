
require "rails-pipeline/symmetric_encryptor"

module RailsPipeline
  module Subscriber
    class << self
      @@registered_models = {}
      def register(payload_class, target_class)
        @@registered_models[payload_class] = target_class
        # We might want to add an extra layer of configuration, to register only some of the CRUD
        # operations, a suggested DSL would be:
        #
        #  RailsPipeline::Subscriber.register(Harrys::Pipeline::Order_1_0, Order) do |config|
        #    config.use_default_handler_for [:create, :update, :destroy]
        #  end
        #
        #  or, to only use update and destroy
        #
        #  RailsPipeline::Subscriber.register(Harrys::Pipeline::Order_1_0, Order) do |config|
        #    config.use_default_handler_for [:update, :destroy]
        #  end
      end

      def target_class(payload_class)
        @@registered_models[payload_class]
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
        payload_str = self.class.decrypt(envelope)
        begin
          clazz = Object.const_get(envelope.type_info)
        rescue NameError
          RailsPipeline.logger.info "Dropping unknown message #{envelope.type_info}"
          return
        end

        payload = clazz.parse(payload_str)
        handle_payload(payload, enveope.event_type)
      end

      def handle_payload(payload, event_type)
        version = _version(payload)
        clazz = target_class(payload)
        method = "from_pipeline_#{version}".to_sym

        if clazz.nil?
          # This message type is not registered for this app
          RailsPipeline.logger.info "Dropping unclaimed message #{payload.class.name}"
          return
        end

        if clazz.is_a?(Class)
          if clazz.methods.include?(method)
            # Target class had a from_pipeline method, so just call it and move on
            target = clazz.send(method, payload, event_type)
          else
            handle_object_action(payload, event_type)
          end
          return target
        elsif clazz.is_a? Proc
          return clazz.call(payload)
        end
      end

      def handle_object_action(payload, event_type)
        # FIXME: Shitty name
        #
        # This method is active record only, we might want to use adapters like:
        # call `RailsPipeline::PersistenceAdapter.create`
        #
        #   and have the adapter defined in their own class:
        #   - RailsPipeline::PersistenceAdapter::ActiveRecord.create
        #   - RailsPipeline::PersistenceAdapter::Mongoid.create
        #   - RailsPipeline::PersistenceAdapter::MyCustomAdapter.create
        #   - ...
        begin
          case event_type
          when RailsPipeline::EncryptedMessage::EventType::CREATED
            return target_class(payload).create!(payload.to_hash, without_protection: true)
          when RailsPipeline::EncryptedMessage::EventType::UPDATED
            # We might want to allow confiugration of the primary key field
            object = target_class(payload).find(payload.id)
            object.update_attributes!(payload.to_hash, without_protection: true)
            return object
          when RailsPipeline::EncryptedMessage::EventType::DELETED
            object = target_class(payload).find(payload.id)
            object.destroy
            return object
          end
        rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound => e
          RailsPipeline.logger.error "Could not handle payload: #{payload.inspect}, event_type: #{event_type}"
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
