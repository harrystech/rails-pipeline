

require 'aws-sdk'

# Backend for data pipeline that publishes to Amazon Simple Notification
# Service (SNS).
#
# Configure via an initializer like:
# PipelineSnsEmitter.account_id = "6982739827398"

module RailsPipeline::SnsPublisher
  class << self
    # Allow configuration via initializer
    @@account_id = nil
    def account_id
      @@account_id
    end
    def account_id=(account_id)
      @@account_id = account_id
    end
  end

  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  module InstanceMethods
    def publish(topic_name, data)
      t0 = Time.now
      topic = _sns.topics[_topic_arn(topic_name)]
      data = data.to_json
      topic.publish(data, subject: _subject, sqs: data)
      t1 = Time.now
      RailsPipeline.logger.debug "Published to SNS '#{topic_name}' in #{t1-t0}s"
    end

    def _sns
      @sns = AWS::SNS.new if @sns.nil?
      return @sns
    end

    def _topic_arn(topic_name, region="us-east-1")
      "arn:aws:sns:#{region}:#{_account_id}:#{topic_name}"
    end

    # Subject of SNS message is ClassName-id
    def _subject
      "#{self.class.name}-#{self.id}"
    end

    def _account_id
      if ENV.has_key?("AWS_ACCOUNT_ID")
        return ENV["AWS_ACCOUNT_ID"]
      end
      return RailsPipeline::SnsPublisher.account_id
    end
  end

  module ClassMethods
  end

end
