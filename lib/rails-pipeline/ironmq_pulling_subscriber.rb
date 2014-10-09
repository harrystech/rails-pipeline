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

        # Valid Parameters at this time are
        # wait_time - An integer indicating how long in seconds we should long poll IronMQ on empty queues
        # interval - An integer indicating how many seconds we should wait between checking for checking for new messages.
        # halt_on_error - A boolean indicating if we should stop our queue subscription if an error occurs
        # halt_on_empty - A boolean indicating whether or not we should stop our queue subscription if we find the queue is empty.
        #                 The `interval` argument is ignored if this is true because subscription ends immediately if there are no
        #                 new messages.
        def start_subscription(params={}, &block)
            wait_time = params[:wait_time] || 2
            interval = params[:interval] || 1
            halt_on_error = params[:halt_on_error].nil? ? true : params[:halt_on_error]
            halt_on_empty = params[:halt_on_empty].nil? ? true : params[:halt_on_empty]

            activate_subscription

            while active_subscription?
                pull_message(wait_time) do |message|
                    if (message.nil? || JSON.parse(message.body).empty?)
                        if halt_on_empty
                            deactivate_subscription
                        else
                            sleep(interval)
                        end
                    else
                        process_message(message, halt_on_error, block)
                    end
                end
            end
        end


        def process_message(message, halt_on_error, block)
            begin
                payload = parse_ironmq_payload(message.body)
                envelope = generate_envelope(payload)
                process_envelope(envelope, message, block)
            rescue Exception => e
                if halt_on_error
                    deactivate_subscription
                end

                RailsPipeline.logger.error "A message was unable to be processed as was not removed from the queue."
                RailsPipeline.logger.error "The message: #{message.inspect}"
                raise e
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

        def process_envelope(envelope, message, block)
            callback_status = block.call(envelope)

            if callback_status
                message.delete
            end
        end

        def pull_message(wait_time)
            queue = _iron.queue(queue_name)
            yield queue.get(:wait => wait_time)
        end

        private

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
