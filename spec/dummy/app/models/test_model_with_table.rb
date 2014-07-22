require_relative "../../../protobuf/test_emitter_1_1.pb"

class TestModelWithTable < ActiveRecord::Base
  include RailsPipeline::Emitter
  include DummyPublisher

  def to_pipeline_1_1
    TestEmitter_1_1.new(id: self.id, foo: (self.foo || 'foo'))
  end
end
