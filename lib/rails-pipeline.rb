
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
    HAS_NEWRELIC = true
  rescue LoadError
    HAS_NEWRELIC = false
  end
end

require "rails-pipeline/emitter"
require "rails-pipeline/subscriber"
require "rails-pipeline/symmetric_encryptor"
require "rails-pipeline/redis_publisher"
require "rails-pipeline/sns_publisher"
require "rails-pipeline/ironmq_publisher"
require "rails-pipeline/handlers/base_handler"
require "rails-pipeline/handlers/activerecord_crud"
require "rails-pipeline/handlers/logger"
