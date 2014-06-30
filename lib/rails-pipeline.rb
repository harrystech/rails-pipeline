

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
    if ENV.has_key?("DISABLE_RAILS_PIPELINE") || ENV.has_key?("DISABLE_RAILS_PIPELINE_EMISSION")
      HAS_NEWRELIC = false
    else
      HAS_NEWRELIC = true
    end
  rescue LoadError
    HAS_NEWRELIC = false
  end
end

require "rails-pipeline/emitter"
require "rails-pipeline/symmetric_encryptor"
require "rails-pipeline/redis_publisher"
require "rails-pipeline/sns_publisher"
require "rails-pipeline/ironmq_publisher"
