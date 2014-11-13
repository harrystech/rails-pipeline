require 'spec_helper'

describe RailsPipeline::BasicEmitter do

    describe ".emit" do
        context "during normal circumstances" do
            let(:publisher){double("A very fancy publisher")}


            it "should publish a message" do
                publisher.should_receive :publish
                RailsPipeline::BasicEmitter.emit("test_message",
                                                 "some_type",
                                                 "an old fashion payload",
                                                 "1.0",
                                                 RailsPipeline::EncryptedMessage::EventType::CREATED,
                                                 publisher)

            end
        end
    end

    describe ".create_message" do
        it "returns an encrypted version of the message" do
            result  = RailsPipeline::BasicEmitter.create_message("test_message",
                                                       "some_type",
                                                       "an old fashion payload",
                                                       "1.0",
                                                       RailsPipeline::EncryptedMessage::EventType::CREATED)

            expect(result.is_a? RailsPipeline::EncryptedMessage).to eql(true)
        end
    end
end
