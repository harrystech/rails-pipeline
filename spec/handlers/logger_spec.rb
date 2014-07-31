require 'spec_helper'
require 'pipeline_helper'

describe RailsPipeline::SubscriberHandler::Logger do
  describe 'handle payload event type' do
    let(:handler) {
      RailsPipeline::SubscriberHandler::Logger.new(
        payload, envelope: test_message)
    }
    let(:test_model) { TestModelWithTable.new({id: 42, foo: 'bar'}, without_protection: true) }
    let(:subscriber) { TestSubscriber.new }
    let(:test_message) { test_model.create_message("1_1", event) }
    let(:payload_str) { subscriber.class.decrypt(test_message) }
    let(:clazz) { Object.const_get(test_message.type_info) }
    let(:payload) { clazz.parse(payload_str) }

    context 'CREATED' do
      let(:event) { RailsPipeline::EncryptedMessage::EventType::CREATED }

      it 'logs everything' do
        expect(RailsPipeline.logger).to receive(:info).with(test_message.to_s)
        handler.handle_payload
      end
    end

    context 'UPDATED' do
      let(:event) { RailsPipeline::EncryptedMessage::EventType::UPDATED }
      it 'logs everything' do
        expect(RailsPipeline.logger).to receive(:info).with(test_message.to_s)
        handler.handle_payload
      end
    end

    context 'DELETED' do
      let(:event) { RailsPipeline::EncryptedMessage::EventType::DELETED }
      it 'logs everything' do
        expect(RailsPipeline.logger).to receive(:info).with(test_message.to_s)
        handler.handle_payload
      end
    end
  end
end
