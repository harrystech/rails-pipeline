require 'spec_helper'
require_relative 'pipeline_helper'

describe RailsPipeline::IronmqPublisher do
  before do
    @default_emitter = DefaultIronmqEmitter.new({foo: "baz"}, without_protection: true)
  end

  it "should call post for IronMQ" do
    allow_any_instance_of(IronMQ::Queue).to receive(:post) { |instance, json_data|
      expect(instance.name).to eq("harrys-#{Rails.env}-v1-default_emitters")
      expect(json_data).to include("encrypted")
    }
    @default_emitter.emit
  end

  it "should actually publish message to IronMQ" do
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
    @default_emitter.emit
  end

end
