# Sinatra endpoints for consuming IronMQ push queues for the rails-pipeline

require 'sinatra'
require 'base64'

module RailsPipeline
  class IronmqSubscriber < Sinatra::Base
    include RailsPipeline::Subscriber

    post '/' do
      t0 = Time.now
      data = request.body.read
      envelope = RailsPipeline::EncryptedMessage.parse(Base64.strict_decode64(data))
      handle_envelope(envelope)
      t1 = Time.now
      RailsPipeline.logger.debug "Consuming from IronMQ: #{envelope.topic} took #{t1-t0}s"
    end

  end
end
