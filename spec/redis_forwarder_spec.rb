
require 'spec_helper'
require 'pipeline_helper'
require 'forwarder_helper'

describe RailsPipeline::RedisForwarder do
  before do
    @emitter = DefaultRedisEmitter.new({foo: "baz"}, without_protection: true)
    @redis_queue = @emitter._key
    @forwarder = DummyRedisForwarder.new(@redis_queue)
    @in_progress_queue = @forwarder._in_progress_queue
    @redis = @emitter._redis
  end


  it "should get the class and version from type_info" do
    type_info = "DefaultEmitter_1_0"
    clazz, version = DummyRedisForwarder._payload_class_and_version(type_info)
    expect(clazz).to eq(DefaultEmitter)
    expect(version).to eq "1_0"
  end

  it "should get the topic from type_info" do
    type_info = "DefaultEmitter_1_0"
    topic = DummyRedisForwarder._topic_name(type_info)
    expect(topic).to eq "harrys-#{Rails.env}-v1-default_emitters"
  end


  context "having one message on the queue" do
    before do
      @redis.del(@redis_queue)
      @redis.del(@in_progress_queue)
      expect(@redis.llen(@redis_queue)).to eq 0
      @emitter.emit  # emit a message

      expect(@redis.llen(@redis_queue)).to eq 1
      expect(@forwarder._processed).to eq 0
    end

    it "should re-publish messages off the queue" do

      # Spy on the publish method
      expect(@forwarder).to receive(:publish).once { |topic, data|
        expect(topic).to eq "harrys-#{Rails.env}-v1-default_emitters"
        expect(data).to include "DefaultEmitter_1_0"
      }

      @forwarder.process_queue

      # We should have processed the one message
      expect(@redis.llen(@redis_queue)).to eq 0
      expect(@forwarder._processed).to eq 1

      # Just check that we can handle an empty queue OK
      @forwarder.process_queue
      expect(@redis.llen(@redis_queue)).to eq 0
      expect(@forwarder._processed).to eq 1
    end

    it "should have an in_progress message temporarily" do
      # Inside the publish method, let's inspect the in_progress queue
      expect(@forwarder).to receive(:publish).once { |topic, data|
        expect(@redis.llen(@in_progress_queue)).to eq 1
        expect(@redis.lrange(@in_progress_queue, 0, 1)[0]).to eq data
      }
      @forwarder.process_queue
      expect(@redis.llen(@in_progress_queue)).to eq 0
    end

    it "should re-queue failed messages" do
      # Check what happens when publish() raises an exception...
      expect(@forwarder).to receive(:publish).once.and_raise("dummy publishing error")
      @forwarder.process_queue # will fail and put it back on the queue
      expect(@redis.llen(@redis_queue)).to eq 1
      expect(@redis.llen(@in_progress_queue)).to eq 0
      expect(@forwarder._processed).to eq 0

      # Now process again with no errors...
      expect(@forwarder).to receive(:publish).once
      @forwarder.process_queue # will fail and put it back on the queue
      expect(@redis.llen(@redis_queue)).to eq 0
      expect(@forwarder._processed).to eq 1
    end

    context "with an abandoned message" do
      before do
        @redis.rpoplpush(@redis_queue, @in_progress_queue)
        expect(@redis.llen(@redis_queue)).to eq 0
        expect(@redis.llen(@in_progress_queue)).to eq 1
      end

      it "should re-queue timed-out in-progress messages" do
        @forwarder.check_for_failures
        expect(@redis.llen(@redis_queue)).to eq 1
        expect(@redis.llen(@in_progress_queue)).to eq 0

      end
    end

    it "should check the in-progress queue at the right times" do
      now = Time.now
      expect(@forwarder).to receive(:check_for_failures).once
      expect(@forwarder).to receive(:process_queue).once.and_call_original
      @forwarder.run
      Timecop.freeze(now + 1.second) {
        expect(@forwarder).not_to receive(:check_for_failures)
        expect(@forwarder).to receive(:process_queue).once.and_call_original
        @forwarder.run
      }
    end
  end
end
