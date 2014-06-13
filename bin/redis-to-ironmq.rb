#!/usr/bin/env ruby

require 'rails-pipeline/redis_ironmq_forwarder'

# Pipeline forwarder that reads from redis queue and forwards to ironmq.
$redis = ENV["REDISCLOUD_URL"] || ENV["REDISTOGO_URL"] || "localhost:6379"

# TODO: non-hardcode this
key = "harrys-www-pipeline"

forwarder = RedisIronmqForwarder.new(key)
forwarder.start
