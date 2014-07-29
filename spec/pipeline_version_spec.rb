require 'spec_helper'

describe RailsPipeline::PipelineVersion do
  context 'major' do
    it "parses the string correctly" do
      expect(RailsPipeline::PipelineVersion.new("1_0").major).to eq(1)
    end
  end

  context 'minor' do
    it "parses the string correctly" do
      expect(RailsPipeline::PipelineVersion.new("1_3").minor).to eq(3)
    end
  end

  describe 'comparison' do
    let(:v1_0) { RailsPipeline::PipelineVersion.new('1_0') }
    let(:v2_0) { RailsPipeline::PipelineVersion.new('2_0') }
    let(:v1_3) { RailsPipeline::PipelineVersion.new('1_3') }
    let(:v1_10) { RailsPipeline::PipelineVersion.new('1_10') }
    let(:v1_10bis) { RailsPipeline::PipelineVersion.new('1_10') }

    it { expect(v1_0).to be < v2_0 }
    it { expect(v1_3).to be > v1_0 }
    it { expect(v1_10).to be < v2_0 }
    it { expect(v1_10).to be > v1_3 }
    it { expect(v1_10).to eq(v1_10bis) }
  end

  describe '#to_s' do
    it "renders correctly" do
      expect("#{RailsPipeline::PipelineVersion.new('2_1')}").to eq("2_1")
    end
  end
end
