
require "rails-pipeline/emitter"
require "rails-pipeline/symmetric_encryptor"
require "rails-pipeline/redis_publisher"
require "rails-pipeline/sns_publisher"
require "rails-pipeline/ironmq_publisher"

module RailsPipeline
  class << self
    # Allow configuration via initializer
    @@logger = nil
    def logger
      if @@logger.nil?
        @@logger = Rails.logger
      end
      @@logger
    end
    def logger=(logger)
      @@logger = logger
    end
  end
  begin
    require 'newrelic_rpm'
    puts "Detected NewRelic"
    HAS_NEWRELIC = true
  rescue LoadError
    HAS_NEWRELIC = false
  end
end
