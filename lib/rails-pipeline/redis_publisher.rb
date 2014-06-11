
require 'redis'

# Backend for data pipeline that publishes to redis queue
# (typically for consumption by a log sender)
#
# Typically initialized in rails initialzer e.g.
# RailsPipeline::RedisPublisher.redis = Redis.new(ENV["REDIS_URL"])
# RailsPipeline::RedisPublisher.namespace = "my-app-pipeline"

module RailsPipeline
  module RedisPublisher
    class << self
      # Allow configuration via initializer
      @@redis = nil
      @@namespace = "pipeline" # default redis queue name
      attr_accessor :namespace
      def _redis
        if @@redis.nil?
          if $redis.start_with?("redis://")
            @@redis = Redis.new(url: $redis)
          else
            host, port = $redis.split(":")
            @@redis = Redis.new(host: host, port: port)
          end
        end
        @@redis
      end
      def redis=(redis)
        @@redis = redis
      end
      def namespace=(namespace)
        @@namespace = namespace
      end
      def namespace
        @@namespace
      end
    end

    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      def publish(topic_name, data)
        t0 = Time.now
        _redis.rpush(_key, data)
        t1 = Time.now
        RailsPipeline.logger.debug "Publishing to redis '#{topic_name}' took #{t1-t0}s"
      end
      def _redis
        RedisPublisher._redis
      end
      def _key
        RedisPublisher.namespace
      end
    end

    module ClassMethods

    end
  end

end
