require 'spec_helper'
require 'pipeline_helper'

describe RailsPipeline::SubscriberHandler::ActiveRecordCRUD do
  describe 'handle payload event type' do
    let(:handler) {
      RailsPipeline::SubscriberHandler::ActiveRecordCRUD.new(
        payload, target_class: subscriber.target_class(payload), event_type: event)
    }
    let(:subscriber) { TestSubscriber.new }
    let(:test_message) { test_model.create_message("1_1", event) }
    let(:payload_str) { subscriber.class.decrypt(test_message) }
    let(:clazz) { Object.const_get(test_message.type_info) }
    let(:payload) { clazz.parse(payload_str) }

    before(:each) do
      RailsPipeline::Subscriber.register(TestEmitter_1_1, TestModelWithTable)
    end

    after(:each) { TestModelWithTable.delete_all }

    context 'CREATED' do
      let(:event) { RailsPipeline::EncryptedMessage::EventType::CREATED }
      let(:test_model) { TestModelWithTable.new({id: 42, foo: 'bar'}, without_protection: true) }

      it "should create an object" do
        expect {
          handler.handle_payload
        }.to change(TestModelWithTable, :count).by(1)
      end

      it "should create with correct attributes" do
        new_object = handler.handle_payload
        new_object.should be_persisted
        new_object.id.should eq(42)
        new_object.foo.should eq('bar')
      end

      it "should log if creation failed" do
        TestModelWithTable.create({id: 42}, without_protection: true)
        RailsPipeline.logger.should_receive(:error).with("Could not handle payload: #{payload.inspect}, event_type: #{event}")
        handler.handle_payload
      end
    end

    context 'UPDATED' do
      let(:event) { RailsPipeline::EncryptedMessage::EventType::UPDATED }
      let(:test_model) { TestModelWithTable.new({id: 42, foo: 'bar'}, without_protection: true) }

      it "should update existing object" do
        test_model.save!
        test_model.foo = 'qux'
        object = handler.handle_payload
        object.should be_persisted
        object.id.should eq(42)
        object.foo.should eq('qux')
      end

      it "should log if update failed" do
        RailsPipeline.logger.should_receive(:error).with("Could not handle payload: #{payload.inspect}, event_type: #{event}")
        handler.handle_payload
      end
    end

    context 'DELETED' do
      let(:event) { RailsPipeline::EncryptedMessage::EventType::DELETED }
      let(:test_model) { TestModelWithTable.new({id: 42, foo: 'bar'}, without_protection: true) }

      it "should update existing object" do
        test_model.save!
        object = handler.handle_payload
        object.should be_destroyed
      end

      it "should log if update failed" do
        RailsPipeline.logger.should_receive(:error).with("Could not handle payload: #{payload.inspect}, event_type: #{event}")
        handler.handle_payload
      end
    end
  end

  describe 'attributes' do
    let(:handler) {
      RailsPipeline::SubscriberHandler::ActiveRecordCRUD.new(
      payload, target_class: subscriber.target_class(payload), event_type: event)
    }
    let(:subscriber) { TestSubscriber.new }
    let(:test_model) { TestModelWithTable.new({foo: 'bar'}, without_protection: true) }
    let(:test_message) { test_model.create_message("1_1", event) }
    let(:payload_str) { subscriber.class.decrypt(test_message) }
    let(:clazz) { Object.const_get(test_message.type_info) }
    let(:payload) { clazz.parse(payload_str) }
    let(:event) { RailsPipeline::EncryptedMessage::EventType::CREATED }

    it 'converts datetime correctly' do
      test_model.save!
      handler._attributes(payload)[:created_at].should be_an_instance_of(DateTime)
    end
  end
end
