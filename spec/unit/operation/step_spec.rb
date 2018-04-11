require "spec_helper"

describe SmashTheState::Operation::Step do
  let!(:subject) { SmashTheState::Operation::Step }
  let!(:implementation) { proc {} }
  let!(:options) { { foo: :bar, side_effect_free: true } }

  describe "#initialize" do
    it "sets the name, implementation, and default options" do
      instance = subject.new(:conquest, options, &implementation)
      expect(instance.implementation).to eq(implementation)
      expect(instance.name).to eq(:conquest)
      expect(instance.options[:foo]).to eq(:bar)
      expect(instance.options[:side_effect_free]).to eq(true)
    end
  end

  describe "#side_effect_free?" do
    let!(:instance) { subject.new(:conquest, {}, &implementation) }

    it "defaults to false" do
      expect(instance.side_effect_free?).to eq(false)
    end

    it "can be set to true" do
      instance.options[:side_effect_free] = true
      expect(instance.side_effect_free?).to eq(true)
    end
  end
end
