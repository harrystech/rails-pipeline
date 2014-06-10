$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "rails-pipeline/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "rails-pipeline"
  s.version     = RailsPipeline::VERSION
  s.authors     = ["Andy O'Neill"]
  s.email       = ["aoneill@harrys.com"]
  s.homepage    = "https://github.com/harrystech/rails-pipeline"
  s.summary     = "Data Pipeline for distributed collection of Rails applications"
  s.description = "Emit versioned changes to a message queue when saving Rails models."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.18"
  s.add_dependency "redis"
  s.add_dependency "iron_mq"
  s.add_dependency "aws-sdk"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "activerecord-tableless"
  s.add_development_dependency "pry"
end
