#!/usr/bin/env ruby

require 'logger'
require 'rails-pipeline'
require 'rails-pipeline/redis_ironmq_forwarder'

log = Logger.new($stdout)
log.progname = 'pipeline'
RailsPipeline::logger = log

# Pipeline forwarder that reads from redis queue and forwards to ironmq.
$redis = ENV["REDISCLOUD_URL"] || ENV["REDISTOGO_URL"] || "localhost:6379"

# TODO: non-hardcode this
key = "harrys-www-pipeline"

forwarder = RailsPipeline::RedisIronmqForwarder.new(key)
forwarder.start
