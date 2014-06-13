
require 'spec_helper'
require 'pipeline_helper'

describe TestBackgroundEmitter do
  before do
    @test_emitter = TestBackgroundEmitter.new({foo: "bar"}, without_protection: true)
  end

  it "should run in the background" do
    @test_emitter.emit
    puts "Sent #emit"
    sleep 2
  end
end
