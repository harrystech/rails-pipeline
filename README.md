# RailsPipeline

Emit a versioned stream of changes to a pub/sub queue when ActiveRecord models are
saved. This gem supports Redis, AWS (SNS/SQS), and IronMQ publishing targets.
The Redis backend supports a forwarding system to a cloud MQ like IronMQ.
Messages are encrypted in transit using AES symmetric encryption and a shared
secret.

## Motivation

Many systems evolve into a inter-related collection of Rails applications as
they grow out of their initial monolithic design. This is often coincident with
independent teams taking responsibility for different aspects of the business
and different applications. In our case this has manifested itself as
one team that is responsible for the ecommerce platform (web, mobile etc) and
another team that works on data warehousing and personalization. The data team
was using a read-only replica of the platform team's database for data
warehousing, which tightly coupled us together when the platform team wanted to
make schema changes for performance or development velocity reasons.

This project allows us to offer a versioned API that we can maintain backwards
compatibility for while changing the underlying code and schema as we see fit.
Consumers of data will upgrade to new schema versions as they need to and when
they are able.

## Usage

Install with bundler

    gem 'rails-pipeline'

You should create a private repository containing your protocolbuffers schemas
and also depend on that, or use `git subtree` to bring it into your Rails apps.

For any models that you wish to publish changes, just include the appropriate
pipeline emitter

    include RailsPipeline::RedisEmitter

Each queue backend has different methods of consuming messages as a subscriber,
but for IronMQ there is an implementation of a webhook subscriber (details
below).

## Backends

### Redis

<table>
<tr><td>Redis Emitter</td><td>Only as a forwarding intermediary</td></tr>
<tr><td>Redis Subscriber</td><td>Only forwarder</td></tr>
</table>

The implementation for Redis assumes you want to use it as a local forwarding
queue to a more scalable service such as AWS or IronMQ. Thus all messages are
pushed onto a single Redis queue and include the name of the target topic/queue.
We have included a bouncer process that will read from the Redis queue (in
parallel if need be) and forward on to IronMQ. Adding an AWS forwarder would be
trivial.

TODO: Config

It may be desirable to write a full pub/sub emitter for Redis (rather than just
a forwarder.)

### IronMQ

<table>
<tr><td>IronMQ Emitter</td><td>YES</td></tr>
<tr><td>Redis-to-IronMQ Forwarder</td><td>YES</td></tr>
<tr><td>IronMQ Subscriber</td><td>YES</td></tr>
</table>

#### Emitter

Each model/version emits ProtocolBuffer messages to a specific IronMQ queue. If
that queue is set as a "push" queue. Subscribers can then add themselves as http
webhook endpoints for the push queue and messages will be delivered to them.


#### Subscriber

There is a subscriber implementation for IronMQ as an http endpoint.

Mount the Sinatra endpoint in your app's routes.rb

    match "/ironmq" => RailsPipeline::IronmqSubscriber, :anchor => false

Register your own models as recipients of different pipeline message types and
versions (in an Rails initializer):

	RailsPipeline::Subscriber.register(SomeModel_2_0, MyModel)

You will need to write a `MyModel#from_pipeline_2_0()` method. You can also
register any Proc as a processor for messages.

Add your URL as a subscriber to the push queues you care about using the
supplied 'pipeline' command

    pipeline ironmq-subscribe-endpoint http://my.domain.com/ironmq some_models

You may find [ngrok](http://ngrok.com) helpful for developing and debugging.

### AWS (Simple Notification Service)

<table>
<tr><td>SNS Emitter</td><td>YES</td></tr>
<tr><td>Redis-to-SNS Forwarder</td><td>NO, but easy to add.</td></tr>
<tr><td>SQS Polling Subscriber</td><td>NO</td></tr>
<tr><td>SNS Webhook Subscriber</td><td>NO</td></tr>
</table>

We include a proof-of-concept AWS emitter, written with the idea in mind to use
SQS as pub/sub queues and polling subscribers. It would also be possible to
publish to SNS and have multiple subscribers receive http webhook messages as in
IronMQ.

There are some commands in the 'pipeline' script to configure SNS/SQS:


Create SNS topics to publish to:

	pipeline sns-create-topic TABLE_NAME --env ENV --version VERSION

Create and SQS queue and subscribe it to a TOPIC (one per subscibing rails
	app)

	pipeline sqs-subscribe-app APP TABLE_NAME[,TABLE_NAME_2,...] --env ENV --version VERSION


## Protocol Buffers

To build the test protocol buffers ruby files in rails-pipeline:

    brew install protobuf
    make

We have created a private repository gem for our protocol buffers definitions.
This is laid out like

	harrys-pipeline/lib/harrys/pipeline/my_model_1_1.proto

Proto files look like this

<pre>
	package Harrys.Pipeline;

	message Order__1__0 {
	  required int32 id = 1;
      required double created_at = 2;
	  required double updated_at = 3;
	  ...
	}
</pre>

We then have a Makefile almost identical to the one in this gem to build our
.pb.rb files:

<pre>
GENDIR=./lib/harrys/pipeline
RUBY_PROTOC=bundle exec ruby-protoc
PROTOS=$(wildcard $(GENDIR)/*.proto)
PBS=$(PROTOS:%.proto=%.pb.rb)

all: $(PBS)

%.pb.rb: %.proto
        $(RUBY_PROTOC) $<

clean:
        rm -f $(PBS)
</pre>

[![TravisCI](https://travis-ci.org/harrystech/rails-pipeline.png)](https://travis-ci.org/harrystech/rails-pipeline)
