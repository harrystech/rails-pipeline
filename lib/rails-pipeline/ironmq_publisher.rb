

require 'iron_mq'

# Backend for data pipeline that publishes to IronMQ
#
# Assumes the following env vars:
# - IRON_TOKEN=MY_TOKEN
# - IRON_PROJECT_ID=MY_PROJECT_ID

module RailsPipeline::IronmqPublisher

  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  module InstanceMethods
    def publish(topic_name, data)
      t0 = Time.now
      queue = _iron.queue(topic_name)
      queue.post(data)
      t1 = Time.now
      RailsPipeline.logger.debug "Publishing to IronMQ: #{topic_name} took #{t1-t0}s"
    end

    def _iron
      @iron = IronMQ::Client.new if @iron.nil?
      return @iron
    end

  end

  module ClassMethods
  end

end
