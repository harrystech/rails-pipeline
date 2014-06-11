# RailsPipeline


Emit a version stream of changes to a pub/sub queue when ActiveRecord models are
saved. This gem supports Redis, AWS (SNS/SQS), and IronMQ publishing targets.
The Redis backend supports a forwarding system to a,cloud MQ like IronMQ.

## Motivation

## Backends

### Redis

### IronMQ

### AWS (Simple Notification Service)

## Forwarders

## Production Suggestions

## Protocol Buffers

   brew install protobuf
   bundle exec ruby-protoc spec/protobuf/*.proto
