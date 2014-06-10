require 'spec_helper'
require_relative 'pipeline_helper'

describe RailsPipeline::SnsPublisher do
  before do
    @default_emitter = DefaultSnsEmitter.new({foo: "baz"}, without_protection: true)
  end

  it "should publish message to SNS" do
    allow_any_instance_of(AWS::SNS::Topic).to receive(:publish) { |instance, message, options|
      options[:subject].should eql "DefaultSnsEmitter-"
      options[:sqs].should eql message
      # message is encrypted, but we tested that in pipeline_emitter_spec
    }
    @default_emitter.emit
  end

  # Skipped since I can't be bothered to set permissions in circle
  skip "should actually send to sns" do
    @default_emitter.emit
  end

end
