#!/usr/bin/env ruby
# Generated by the protocol buffer compiler. DO NOT EDIT!

require 'protocol_buffers'

# forward declarations
class TestEmitter_2_0 < ::ProtocolBuffers::Message; end

class TestEmitter_2_0 < ::ProtocolBuffers::Message
  set_fully_qualified_name "TestEmitter__2__0"

  required :int32, :id, 1
  required :string, :foo, 2
  optional :string, :extra, 3
end

