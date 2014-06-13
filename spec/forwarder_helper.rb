
require 'rails-pipeline/redis_forwarder'

class DummyRedisForwarder < RailsPipeline::RedisForwarder
  def publish(topic, data)
    puts "Dummy publish to: #{topic}"
  end
end
