require "spec_helper"

require "pipeline_helper"

describe RailsPipeline::SymmetricEncryptor do
  before do
    @plaintext = "Stately, plump Buck Mulligan came from the stairhead, bearing a bowl of lather on which a mirror and a razor lay crossed."
  end

  it "should round-trip encrypt string" do
    payload = DefaultEmitter.encrypt(@plaintext)
    expect(payload.salt).not_to be_nil
    expect(payload.iv).not_to be_nil
    expect(payload.ciphertext).not_to be_nil


    roundtrip = DefaultEmitter.decrypt(payload)
    expect(roundtrip).to eq(@plaintext)
  end

end
