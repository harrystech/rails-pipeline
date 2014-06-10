
require "rails-pipeline/emitter"
require "rails-pipeline/symmetric_encryptor"
require "rails-pipeline/redis_publisher"
require "rails-pipeline/sns_publisher"
require "rails-pipeline/ironmq_publisher"

module RailsPipeline

  def self.logger
    Rails.logger
  end
end
