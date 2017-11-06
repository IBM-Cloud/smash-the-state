require "spec_helper"

describe SmashTheState::Operation::Step do
  let!(:subject) { SmashTheState::Operation::Step }

  describe "#initialize" do
    let!(:implementation) { proc {} }

    it "sets the name and implementation" do
      instance = subject.new(:conquest, &implementation)
      expect(instance.implementation).to eq(implementation)
      expect(instance.name).to eq(:conquest)
    end
  end
end
