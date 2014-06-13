
require 'rails-pipeline/redis_forwarder'
require 'rails-pipeline/ironmq_publisher'

# Mix-in the IronMQ publisher into a RedisForwarder to create a
# class that will forward redis messages onto IronMQ

module RailsPipeline
  class RedisIronmqForwarder < RedisForwarder
    include IronmqPublisher
  end
end
