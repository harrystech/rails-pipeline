
require 'spec_helper'
require 'pipeline_helper'

describe RailsPipeline::Subscriber do
  before do
    @test_emitter = TestEmitter.new({foo: "bar"}, without_protection: true)

    @test_message = @test_emitter.create_message("2_0", false)
    @subscriber = TestSubscriber.new
  end

  it "should handle correct messages" do
    expect(@subscriber).to receive(:handle_payload).once
    @subscriber.handle_envelope(@test_message)
  end

  it "should raise exception on malformed messages" do
    @test_message = RailsPipeline::EncryptedMessage.new(salt: "jhkjehd", iv: "khdkjehdkejhdkjehdkjhed")
    expect(@subscriber).not_to receive(:handle_payload)
    expect{@subscriber.handle_envelope(@test_message)}.to raise_error
  end


  context "with decrypted payload" do
    before do
      @payload_str = @subscriber.class.decrypt(@test_message)
      clazz = Object.const_get(@test_message.type_info)
      @payload = clazz.parse(@payload_str)
    end

    it "should get the version right" do
      expect(@payload.class.name).to eq "TestEmitter_2_0"
      version = @subscriber._version(@payload)
      expect(version).to eq "2_0"
    end

    context "with registered target class" do
      before do
        RailsPipeline::Subscriber.register(TestEmitter_2_0, TestModel)
      end

      it "should map to the right target" do
        expect(@subscriber.target_class(@payload)).to eq TestModel
      end

      it "should instantiate a target" do
        expect(TestModel).to receive(:new).once.and_call_original
        allow_any_instance_of(TestModel).to receive(:save!)
        target = @subscriber.handle_payload(@payload)
        expect(target.foo).to eq @payload.foo
      end
    end

    context "with a registered target Proc" do
      before do
        @called = false
        RailsPipeline::Subscriber.register(TestEmitter_2_0, Proc.new {
          @called = true
        })
      end

      it "should map to the right target" do
        expect(@subscriber.target_class(@payload).is_a?(Proc)).to eq true
      end

      it "should run the proc" do
        @subscriber.handle_payload(@payload)
        expect(@called).to eq true
      end
    end


    context "without registered target" do
      before do
        RailsPipeline::Subscriber.register(TestEmitter_2_0, nil)
      end

      it "should not instantiate a target" do
        @subscriber.handle_payload(@payload)
      end
    end
  end

  describe 'handle payload event type' do
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
          subscriber.handle_object_action(payload, event)
        }.to change(TestModelWithTable, :count).by(1)
      end

      it "should create with correct attributes" do
        new_object = subscriber.handle_object_action(payload, event)
        new_object.should be_persisted
        new_object.id.should eq(42)
        new_object.foo.should eq('bar')
      end

      it "should log if creation failed" do
        TestModelWithTable.create({id: 42}, without_protection: true)
        RailsPipeline.logger.should_receive(:error).with("Could not handle payload: #{payload.inspect}, event_type: #{event}")
        subscriber.handle_object_action(payload, event)
      end
    end

    context 'UPDATED' do
      let(:event) { RailsPipeline::EncryptedMessage::EventType::UPDATED }
      let(:test_model) { TestModelWithTable.new({id: 42, foo: 'bar'}, without_protection: true) }

      it "should update existing object" do
        test_model.save!
        test_model.foo = 'qux'
        object = subscriber.handle_object_action(payload, event)
        object.should be_persisted
        object.id.should eq(42)
        object.foo.should eq('qux')
      end

      it "should log if update failed" do
        RailsPipeline.logger.should_receive(:error).with("Could not handle payload: #{payload.inspect}, event_type: #{event}")
        subscriber.handle_object_action(payload, event)
      end
    end

    context 'DELETED' do
      let(:event) { RailsPipeline::EncryptedMessage::EventType::DELETED }
      let(:test_model) { TestModelWithTable.new({id: 42, foo: 'bar'}, without_protection: true) }

      it "should update existing object" do
        test_model.save!
        object = subscriber.handle_object_action(payload, event)
        object.should be_destroyed
      end

      it "should log if update failed" do
        RailsPipeline.logger.should_receive(:error).with("Could not handle payload: #{payload.inspect}, event_type: #{event}")
        subscriber.handle_object_action(payload, event)
      end
    end
  end
end

