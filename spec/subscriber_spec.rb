
require 'spec_helper'
require 'pipeline_helper'

describe RailsPipeline::Subscriber do
  before do
    @test_emitter = TestEmitter.new({foo: "bar"}, without_protection: true)

    @test_message = @test_emitter.create_message("2_0", RailsPipeline::EncryptedMessage::EventType::CREATED)
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

  describe 'api_key' do
    before do
      @test_message = @test_emitter.create_message("2_0", RailsPipeline::EncryptedMessage::EventType::CREATED)
    end

    context 'with wrong api key' do
      it "should drop messages" do
        @test_message.api_key = '123XYZ'
        expect{@subscriber.handle_envelope(@test_message)}.to raise_error(RailsPipeline::Subscriber::WrongApiKeyError)
      end
    end

    context 'with no api key' do
      it "should drop messages" do
        @test_message.api_key = nil
        expect{@subscriber.handle_envelope(@test_message)}.to raise_error(RailsPipeline::Subscriber::NoApiKeyError)
      end
    end

    context 'with a correct api key' do
      it "should accept the envelope with correct api_key" do
        stub_const('ENV', {'PIPELINE_API_KEYS' => '123XYZ'})
        @test_message.api_key = '123XYZ'
        expect{@subscriber.handle_envelope(@test_message)}.not_to raise_error
      end

      it "should accept the envelope with any correct api_key" do
        stub_const('ENV', {'PIPELINE_API_KEYS' => '123XYZ,456UVW'})
        @test_message.api_key = '456UVW'
        expect{@subscriber.handle_envelope(@test_message)}.not_to raise_error
      end
    end
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

      context 'without handler' do
        it "should map to the right target" do
          expect(@subscriber.target_class(@payload)).to eq TestModel
        end

        it "should instantiate a target" do
          expect(TestModel).to receive(:new).once.and_call_original
          expect(TestModel).to receive(:from_pipeline_2_0).once.and_call_original
          allow_any_instance_of(TestModel).to receive(:save!)
          target = @subscriber.handle_payload(@payload, @test_message)
          expect(target.foo).to eq @payload.foo
        end
      end

      context 'with a handler' do
        before do
          RailsPipeline::Subscriber.register(
            TestEmitter_2_0, TestModel, RailsPipeline::SubscriberHandler::ActiveRecordCRUD)
        end

        it 'should map to the correct handler' do
          expect(@subscriber.target_handler(@payload)).to eq(RailsPipeline::SubscriberHandler::ActiveRecordCRUD)
        end

        it 'should call the correct handler' do
          expect_any_instance_of(RailsPipeline::SubscriberHandler::ActiveRecordCRUD).to receive(:handle_payload).once
          target = @subscriber.handle_payload(@payload, @test_message)
        end
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
        @subscriber.handle_payload(@payload, @test_message)
        expect(@called).to eq true
      end
    end


    context "without registered target" do
      before do
        RailsPipeline::Subscriber.register(TestEmitter_2_0, nil)
      end

      it "should not instantiate a target" do
        @subscriber.handle_payload(@payload, @test_message)
      end
    end
  end

end

