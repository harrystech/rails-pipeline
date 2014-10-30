
require 'spec_helper'
require 'pipeline_helper'

describe RailsPipeline::Subscriber do
  before do
    @test_emitter = TestEmitter.new({foo: "bar"}, without_protection: true)

    @test_message = @test_emitter.create_message("2_0", RailsPipeline::EncryptedMessage::EventType::CREATED)
    @subscriber = TestSubscriber.new
    TestSubscriber.handler_method_cache = {}
    OtherSubscriber.handler_method_cache = {}
  end


  context "when there is no compatible version registered for the message" do
      before do
        RailsPipeline::Subscriber.register(TestEmitter_2_0, TestModel)
      end

      it "should handle correct messages" do
          expect(@subscriber).to receive(:handle_payload).once
          @subscriber.handle_envelope(@test_message)
      end
  end

  context "when there is a compatible version registered for the message" do
      it "should log the inability to process the message" do
          expect(RailsPipeline.logger).to receive(:info).once
          @subscriber.handle_envelope(@test_message)
      end
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
      expect(version).to eq RailsPipeline::PipelineVersion.new("2_0")
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

  describe '#most_suitable_method' do
    let(:subscriber) { TestSubscriber.new }
    let(:fake_class) { Class.new }
    before do
      stub_const("TestClass", fake_class)
      # Clear TestSubscriber cache
      TestSubscriber.handler_method_cache = {}
    end

    context 'when receiver class has the correct version method' do
      before do
        TestClass.define_singleton_method(:from_pipeline_1_1) { }
      end
      let(:version) { RailsPipeline::PipelineVersion.new('1_1') }
      it 'picks the method' do
        subscriber.most_suitable_handler_method_name(version, TestClass).should eq(:from_pipeline_1_1)
      end
    end

    context 'when receiver class has a handler with same major and lower minor handler method' do
      before do
        TestClass.define_singleton_method(:from_pipeline_1_0) { }
      end
      let(:version) { RailsPipeline::PipelineVersion.new('1_1') }
      it 'picks the method' do
        subscriber.most_suitable_handler_method_name(version, TestClass).should eq(:from_pipeline_1_0)
      end
    end

    context 'when receiver has multiple methods defined' do
      before do
        TestClass.define_singleton_method(:from_pipeline_1_0) { }
        TestClass.define_singleton_method(:from_pipeline_1_5) { }
        TestClass.define_singleton_method(:from_pipeline_1_2) { }
        TestClass.define_singleton_method(:from_pipeline_1_1) { }
      end
      let(:version) { RailsPipeline::PipelineVersion.new('1_4') }
      it 'picks the closest lower method' do
        subscriber.most_suitable_handler_method_name(version, TestClass).should eq(:from_pipeline_1_2)
      end
    end

    context 'when receiver has multiple methods defined' do
      before do
        TestClass.define_singleton_method(:from_pipeline_1_2) { }
        TestClass.define_singleton_method(:from_pipeline_1_0) { }
        TestClass.define_singleton_method(:from_pipeline_1_4) { }
        TestClass.define_singleton_method(:from_pipeline_1_5) { }
      end
      let(:version) { RailsPipeline::PipelineVersion.new('1_4') }
      it 'picks the closest lower method' do
        subscriber.most_suitable_handler_method_name(version, TestClass).should eq(:from_pipeline_1_4)
      end
    end

    context 'when receiver class does not have a handler method' do
      let(:version) { RailsPipeline::PipelineVersion.new('1_1') }
      it 'returns nil' do
        subscriber.most_suitable_handler_method_name(version, TestClass).should be_nil
      end
    end
  end

  context 'methods cache' do
    let(:subscriber) { TestSubscriber.new }
    let(:other_subscriber) { OtherSubscriber.new }
    let(:version) { RailsPipeline::PipelineVersion.new('1_1') }
    let(:fake_class) { Class.new }
    before do
      stub_const("TestClass", fake_class)
      TestClass.define_singleton_method(:from_pipeline_1_0) { }
    end

    it 'exists' do
      TestSubscriber.handler_method_cache.should_not be_nil
    end

    context 'with empty cache' do

      it 'caches method handler for version' do
        subscriber.most_suitable_handler_method_name(version, TestClass)
        TestSubscriber.handler_method_cache[version].should eq(:from_pipeline_1_0)
      end
    end

    context 'with non empty cache' do
      before do
        # warms the cache
        subscriber.most_suitable_handler_method_name(version, TestClass)
      end

      it "reads value from cache" do
        TestClass.should_not_receive(:methods)
        TestSubscriber.handler_method_cache.should_receive(:[]).with(version).once.and_call_original
        subscriber.most_suitable_handler_method_name(version, TestClass)
      end
    end

    context 'cache is attached to each class' do
      let(:fake_class2) { Class.new }
      before do
        stub_const("TestClass2", fake_class2)
        TestClass2.define_singleton_method(:from_pipeline_1_1) { }
        TestClass2.define_singleton_method(:from_pipeline_2_0) { }
      end
      let(:v1_1) { RailsPipeline::PipelineVersion.new('1_1') }
      let(:v2_0) { RailsPipeline::PipelineVersion.new('2_0') }

      it 'caches methods in separate buckets' do
        subscriber.most_suitable_handler_method_name(v1_1, TestClass)
        other_subscriber.most_suitable_handler_method_name(v1_1, TestClass2)
        other_subscriber.most_suitable_handler_method_name(v2_0, TestClass2)
        TestSubscriber.handler_method_cache != OtherSubscriber.handler_method_cache
        TestSubscriber.handler_method_cache.length.should eq(1)
        OtherSubscriber.handler_method_cache.length.should eq(2)
      end
    end
  end

end

