require 'spec_helper'
require_relative 'pipeline_helper'

describe RailsPipeline::IronmqPublisher do
  before do
    @default_emitter = DefaultIronmqEmitter.new({foo: "baz"}, without_protection: true)
  end

  it "should call post for IronMQ" do
    expect_any_instance_of(IronMQ::Queue).to receive(:post) { |instance, serialized_encrypted_data|
      base64_decoded_data = Base64.strict_decode64(serialized_encrypted_data)
      encrypted_data = RailsPipeline::EncryptedMessage.parse(base64_decoded_data)
      serialized_payload = DefaultEmitter.decrypt(encrypted_data)
      data = DefaultEmitter_1_0.parse(serialized_payload)

      expect(instance.name).to eq("harrys-#{Rails.env}-v1-default_emitters")
      expect(encrypted_data.type_info).to eq(DefaultEmitter_1_0.to_s)
      expect(data.foo).to eq("baz")
    }.once
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
