
# Brief makefile to create ruby objects from protocol buffer definitions

GENDIR=./lib/rails-pipeline/protobuf
RUBY_PROTOC=bundle exec ruby-protoc
PROTOS=$(wildcard $(GENDIR)/*.proto)
PBS=$(PROTOS:%.proto=%.pb.rb)

all: $(PBS)

%.pb.rb: %.proto
	$(RUBY_PROTOC) $<

clean:
	rm -f $(PBS)

debug:
	echo $(PROTOS)
	echo $(PBS)
