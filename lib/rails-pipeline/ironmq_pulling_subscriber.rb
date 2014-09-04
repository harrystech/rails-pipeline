require 'base64'
require 'json'

module RailsPipeline
    class IronmqPullingSubscriber
        include RailsPipeline::Subscriber

        attr_reader :queue_name

        def initialize(queue_name)
            @queue_name  = queue_name
            @subscription_status = false
        end

        def start_subscription(&block)
            activate_subscription

            while active_subscription?
                pull_message do |message|
                    if message.nil?
                        deactivate_subscription
                    else
                        payload = parse_ironmq_payload(message.body)
                        envelope = generate_envelope(payload)

                        callback_status = block.call(envelope)

                        if callback_status
                            message.delete
                        end
                    end
                end
            end
        end

        def active_subscription?
            @subscription_status
        end

        def activate_subscription
            @subscription_status = true
        end

        def deactivate_subscription
            @subscription_status = false
        end


        private

        #the wait time on this may need to be changed
        #haven't seen rate limit info on these calls but didnt look
        #all that hard either.
        def pull_message
            queue = _iron.queue(queue_name)
            yield queue.get(:wait => 2)
        end

        def _iron
            @iron = IronMQ::Client.new if @iron.nil?
            return @iron
        end

        def parse_ironmq_payload(message_body)
            payload = JSON.parse(message_body)["payload"]
            Base64.strict_decode64(payload)
        end

        def generate_envelope(payload)
            RailsPipeline::EncryptedMessage.parse(payload)
        end

    end
end
