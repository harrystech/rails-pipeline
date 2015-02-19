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

  s.files = Dir["{app,config,db,lib,bin}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files = Dir["spec/**/*spec.rb"]

  s.add_dependency "rails", "~> 3.2"
  s.add_dependency "redis"
  s.add_dependency "iron_mq"
  s.add_dependency "aws-sdk", "< 2.0"
  s.add_dependency "ruby-protocol-buffers", "~> 1.5.1"
  s.add_dependency "sinatra"

end
