require 'spec_helper'

describe RailsPipeline::IronmqPullingSubscriber do
    let(:subject){RailsPipeline::IronmqPullingSubscriber.new("test_queue")}
    let(:failing_proc){Proc.new{false}}
    let(:successful_proc){Proc.new{true}}

    describe "#start_subscription" do
        it "should attempt to process a dequeued message" do
            subject.stub(:pull_message).and_yield("foo")
            subject.stub(:process_message){subject.deactivate_subscription}
            subject.start_subscription{}
            expect(subject).to have_received(:process_message)
        end
    end

    describe "#process_message" do
        context "when receiving a nil message" do
            it "deactivates the current subscription" do
                subject.process_message(nil,successful_proc)
                expect(subject.active_subscription?).to eql false
            end
        end

        context "when receiving a non-nil message" do
            context "when an issue occurs while generating an message envelope" do
                let(:malformed_message){double("message", :body => "a malformed message",
                                               :delete => "a fine deletion implementation")}

                before(:each) do
                    subject.activate_subscription
                    subject.process_message(malformed_message,successful_proc)
                end

                it "does not delete the message" do
                    expect(malformed_message).to_not have_received(:delete)
                end

                it "deactivates the subscription" do
                    expect(subject.active_subscription?).to eql false
                end
            end
        end
    end

    describe "#handle_envelope" do
        let(:failing_proc){Proc.new{false}}
        let(:successful_proc){Proc.new{true}}
        let(:test_envelope){double("envelope")}
        let(:message){double("message", :delete => "a deletion implementation")}

        context "when the block passed returns true" do
            it "deletes the passed message" do
                subject.handle_envelope(test_envelope, message, successful_proc)
                expect(message).to have_received(:delete)
            end
        end

        context "when the block passeed returns false" do
            it "does not delete the passed message" do
                subject.handle_envelope(test_envelope, message, failing_proc)
                expect(message).to_not have_received(:delete)
            end
        end
    end

    describe "#active_subscription?" do
        context "when the subscriber is currently active" do
            it "returns true" do
                subject.activate_subscription
                expect(subject.active_subscription?).to eq true
            end
        end

        context "when the subscriber is not currently active" do
            it "returns false" do
                subject.deactivate_subscription
                expect(subject.active_subscription?).to eq false
            end
        end
    end

    describe "activate_subscription" do
        it "sets the subscription status of the subscriber to true" do
            subject.deactivate_subscription
            subject.activate_subscription
            expect(subject.active_subscription?).to eql true
        end
    end

    describe "deactivate_subscription" do
        it "sets the subscription status of the subscriber to false" do
            subject.activate_subscription
            subject.deactivate_subscription
            expect(subject.active_subscription?).to eql false
        end
    end
end
