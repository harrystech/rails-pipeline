
require 'spec_helper'
require_relative 'pipeline_helper'

describe RailsPipeline::RedisPublisher do
  before do
    @test_emitter = TestRedisEmitter.new({foo: "bar"}, without_protection: true)
    @default_emitter = DefaultRedisEmitter.new({foo: "baz"}, without_protection: true)
  end

  it "should publish message to Redis" do
    Redis.any_instance.should_receive(:rpush).once { |instance, key, serialized_encrypted_data|
      key.should eql RailsPipeline::RedisPublisher.namespace
      encrypted_data = RailsPipeline::EncryptedMessage.parse(serialized_encrypted_data)
      expect(encrypted_data.type_info).to eq(DefaultEmitter_1_0.to_s)
      serialized_payload = DefaultEmitter.decrypt(encrypted_data)
      data = DefaultEmitter_1_0.parse(serialized_payload)
      expect(data.foo).to eq("baz")
      # message is encrypted, but we tested that in pipeline_emitter_spec
    }
    @default_emitter.emit
  end

  it "just print some timings" do
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
  end


end
