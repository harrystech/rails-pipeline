module RailsPipeline
  # A thin wrapper around our version object
  # A version has the form X_Y where
  #   - X is the major version
  #   - Y is the minor version
  #
  # example: 1_0, 2_1, etc...
  class PipelineVersion

    include Comparable

    attr_reader :major, :minor

    def initialize(version_string)
      # raise error?
      @major, @minor = version_string.split('_').map(&:to_i)
    end

    def to_s
      "#{major}_#{minor}"
    end

    def <=>(other)
      if major == other.major
        return minor <=> other.minor
      else
        return major <=> other.major
      end
    end

    def eql?(other)
      return to_s.eql?(other.to_s)
    end

    def hash
      return to_s.hash
    end

  end
end
