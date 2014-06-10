
require 'spec_helper'
require_relative 'pipeline_helper'

describe RailsPipeline::RedisPublisher do
  before do
    @test_emitter = TestRedisEmitter.new({foo: "bar"}, without_protection: true)
    @default_emitter = DefaultRedisEmitter.new({foo: "baz"}, without_protection: true)
  end

  it "should publish message to Redis" do
    Redis.any_instance.should_receive(:rpush).once { |instance, key, data|
      key.should eql RailsPipeline::RedisPublisher.namespace
      data.should_not be_nil
      data.should include "encrypted"
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
