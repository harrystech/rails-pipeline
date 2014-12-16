require 'spec_helper'

describe RailsPipeline::BasicEmitter do
    let(:payload){{
        :topic => "test_message",
        :type_info =>  "some_type",
        :payload =>  "an old fashion payload",
        :version => "1.0",
        :event_type => RailsPipeline::EncryptedMessage::EventType::CREATED}}

    let(:publisher){double("A very fancy publisher")}

    describe ".emit" do
        context "during normal circumstances" do
            it "should publish a message" do
                publisher.should_receive :publish
                RailsPipeline::BasicEmitter.emit(payload, publisher)
            end
        end
    end

    describe ".create_message" do
        it "returns an encrypted version of the message" do
            result  = RailsPipeline::BasicEmitter.create_message(payload)
            expect(result).to be_a(RailsPipeline::EncryptedMessage)
        end
    end
end
