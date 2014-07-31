
require_relative "protobuf/default_emitter_1_0.pb"
require_relative "protobuf/test_emitter_1_1.pb"
require_relative "protobuf/test_emitter_2_0.pb"

# Test data

module DummyPublisher
  def self.included(base)
    # base.extend PublisherClassMethods
    base.send :include, PublisherInstanceMethods
  end

  module PublisherInstanceMethods
    def publish(topic_name, data)
      puts "Publishing to dummy '#{topic_name}'"
    end
  end

end

# Class with versioned emitter
class TestModel < ActiveRecord::Base
  has_no_table  # using activerecord-tableless gem

  column :foo, :string

  def self.table_name
    "test_emitters"
  end

  # Implement a backwards-compatible versioned pipeline format
  def to_pipeline_1_1
    TestEmitter_1_1.new(id: 1,
                        foo: foo,
                        extrah: "hi")
  end

  # Implement a non-backwards-compatible versioned pipeline format
  def to_pipeline_2_0
    TestEmitter_2_0.new(id: 1,
                        foo: "modified_#{foo}",
                        extra: "hi")
  end

  def self.from_pipeline_2_0(msg, event_type)
    instance = TestModel.new
    instance.foo = msg.foo
    return instance
  end

  def kinda_attributes
    data = attributes
    data[:id] = 1
    return data
  end

end

# Class that will have v1.0 emitter
class DefaultModel < ActiveRecord::Base
  has_no_table  # using activerecord-tableless gem

  column :foo, :string

  def self.table_name
    "default_emitters"
  end

  def to_pipeline_1_0
    DefaultEmitter_1_0.new(kinda_attributes)
  end

  def kinda_attributes
    data = attributes
    data[:id] = 1
    return data
  end
end

class TestEmitter < TestModel
  include RailsPipeline::Emitter
  include DummyPublisher
end

class DefaultEmitter < DefaultModel
  include RailsPipeline::Emitter
  include DummyPublisher
end

# Dummy Redis models
class TestRedisEmitter < TestModel
  include RailsPipeline::Emitter
  include RailsPipeline::RedisPublisher
end
class DefaultRedisEmitter < DefaultModel
  include RailsPipeline::Emitter
  include RailsPipeline::RedisPublisher
end

# Dummy SNS model
class DefaultSnsEmitter < DefaultModel
  include RailsPipeline::Emitter
  include RailsPipeline::SnsPublisher
end

# Dummy IronMQ model
class DefaultIronmqEmitter < DefaultModel
  include RailsPipeline::Emitter
  include RailsPipeline::IronmqPublisher
end

class TestSubscriber
  include RailsPipeline::Subscriber
end

class OtherSubscriber
  include RailsPipeline::Subscriber
end
