

# Test data

module DummyPublisher
  def self.included(base)
    #base.extend PublisherClassMethods
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
  include RailsPipeline::Emitter

  column :foo, :string

  def self.table_name
    "test_emitters"
  end

  # Implement a backwards-compatible versioned pipeline format
  def to_pipeline_1_1
    data = to_pipeline_1_0
    data["extra"] = "hi"
    return data
  end

  # Implement a non-backwards-compatible versioned pipeline format
  def to_pipeline_2_0
    data = to_pipeline_1_0
    data["extra"] = "hi"
    data["foo"] = "modified_#{foo}"
    return data
  end

end

# Class that will have default emitter
class DefaultModel < ActiveRecord::Base
  has_no_table  # using activerecord-tableless gem
  include RailsPipeline::Emitter

  column :foo, :string

  def self.table_name
    "default_emitters"
  end
end

class TestEmitter < TestModel
  include DummyPublisher
end

class DefaultEmitter < DefaultModel
  include DummyPublisher
end

# Dummy Redis models
class TestRedisEmitter < TestModel
  include RailsPipeline::RedisPublisher
end
class DefaultRedisEmitter < DefaultModel
  include RailsPipeline::RedisPublisher
end

# Dummy SNS model
class DefaultSnsEmitter < DefaultModel
  include RailsPipeline::SnsPublisher
end

# Dummy IronMQ model
class DefaultIronmqEmitter < DefaultModel
  include RailsPipeline::IronmqPublisher
end
