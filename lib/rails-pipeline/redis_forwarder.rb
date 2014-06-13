
require 'redis'

require 'rails-pipeline/protobuf/encrypted_message.pb'

# Pipeline forwarder base class that
#   - reads from redis queue using BRPOPLPUSH for reliable queue pattern
#   - keeps track of failed tasks in the in_progress queue
#   - designed to be used with e.g. IronmqPublisher

$redis = ENV["REDISCLOUD_URL"] || ENV["REDISTOGO_URL"] || "localhost:6379"

module RailsPipeline
  class RedisForwarder

    def initialize(key)
      _trap_signals
      @redis = nil
      @stop = false
      @queue = key
      @in_progress_queue = _in_progress_queue

      @processed = 0
      @blocking_timeout = 1
      @failure_check_interval = 30
      @message_processing_limit = 10 # number of seconds before a message is considered failed
      @failure_last_checked = Time.now - @failure_check_interval.seconds  # TODO: randomize start time?
    end

    def _trap_signals
      trap('SIGTERM') do
        puts 'Exiting (SIGTERM)'
        stop
      end
      trap('SIGINT') do
        puts 'Exiting (SIGINT)'
        stop
      end
    end


    # Blocking right pop from the queue
    #    - use BRPOPLPUSH to tenporarily mark the message as "in progress"
    #    - delete from the in_prgress queue on success
    #    - restore to the main queue on failure
    def process_queue
      # pop from the queue and push onto the in_progress queue
      data = _redis.brpoplpush(@queue, @in_progress_queue, timeout: @blocking_timeout)
      if data.nil?  # Timed-out with nothing to process
        return
      end

      begin
        encrypted_data = RailsPipeline::EncryptedMessage.parse(data)
        puts "Processing #{encrypted_data.uuid}"

        # re-publish to wherever (e.g. IronMQ)
        topic_name = self.class._topic_name(encrypted_data.type_info)
        publish(topic_name, data)
        @processed += 1

        # Now remove this message from the in_progress queue
        removed = _redis.lrem(@in_progress_queue, 1, data)
        if removed != 1
          puts "OHNO! Didn't remove the data I was expecting to: #{data}"
        end
      rescue Exception => e
        puts e
        puts e.backtrace.join("\n")
        if !data.nil?
          puts "Putting message #{encrypted_data.uuid} back on main queue"
          _put_back_on_queue(data)
        end
      end
    end

    # note in redis that we are processing this message
    def report(uuid)
      _redis.setex(_report_key(uuid), @message_processing_limit, _client_id)
    end

    # Search the in-progress queue for messages that are likely to be abandoned
    # and re-queue them on the main queue
    def check_for_failures
      # Lock in_progress queue or return
      num_in_progress = _redis.llen(@in_progress_queue)

      # Attempt to lock this queue for the next num_in_progress seconds
      lock_key = "#{@in_progress_queue}__lock"
      locked = _redis.set(lock_key, _client_id, ex: num_in_progress, nx: true)
      if !locked
        puts "in progress queue is locked"
        return
      end

      # Go through each message, see if there's a 'report' entry. If not,
      # requeue!
      in_progress = _redis.lrange(@in_progress_queue, 0, num_in_progress)
      in_progress.each do |message|
        enc_message = EncryptedMessage.parse(message)
        owner = _redis.get(_report_key(enc_message.uuid))
        if owner.nil?
          puts "Putting timed-out message #{enc_message.uuid} back on main queue"
          _put_back_on_queue(message)
        else
          puts "Message #{uuid} is owned by #{owner}"
        end
      end
    end

    # Function that runs in the loop
    def run
      process_queue
      puts "Processed: #{@processed}"
      if Time.now - @failure_last_checked > @failure_check_interval
        @failure_last_checked = Time.now
        check_for_failures
      end
    end

    # Main loop
    def start
      while true
        begin
          if @stop
            puts "Finished"
            break
          end
          run
        rescue Exception => e
          puts e
          puts e.backtrace.join("\n")
        end
      end
    end

    def stop
      puts "stopping..."
      @stop = true
    end

    def _redis
      if !@redis.nil?
        return @redis
      end
      if $redis.start_with?("redis://")
        @redis = Redis.new(url: $redis)
      else
        host, port = $redis.split(":")
        @redis = Redis.new(host: host, port: port)
      end
      return @redis
    end

    def _processed
      return @processed
    end

    def _in_progress_queue
      "#{@key}_in_progress"
    end

    def _report_key(uuid)
      "#{@queue}__#{uuid}"
    end

    def _client_id
      self.class.name
    end

    # Atomically remove a message from the in_progress queue and put it back on
    # the main queue
    def _put_back_on_queue(message)
      future = nil
      _redis.multi do
        _redis.lpush(@queue, message)
        future = _redis.lrem(@in_progress_queue, 1, message)
      end
      removed = future.value
      if removed !=1
        puts "ERROR: Didn't remove message from in_progress queue?!!!"
      end
    end

    # Figure out the destination queue topic name based on the EncryptedMessage
    # type info
    def self._topic_name(type_info)
      clazz, version = _payload_class_and_version(type_info)
      return clazz.topic_name(version)
    end

    # Parse the encrypted payload class and version from
    # EncryptedMessage.type_info
    def self._payload_class_and_version(type_info)
      class_name, version = type_info.split("_", 2)
      clazz = Object::const_get(class_name)
      return clazz, version
    end
  end
end