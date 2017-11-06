require "spec_helper"
require "json"

describe SmashTheState::Operation::State do
  let!(:subject) { SmashTheState::Operation::State }

  describe "self#build" do
    let!(:built) do
      subject.build do
        attr_accessor :bread
      end
    end

    it "creates a new inherited class and class_evals the block" do
      expect(built < SmashTheState::Operation::State).to eq(true)
      expect(built.new.respond_to?(:bread)).to eq(true)
    end
  end

  describe "self#eval_validation_directives_block" do
    let!(:built) do
      subject.build do
        attribute :bread, :string
      end
    end

    let!(:instance) { built.new }

    it "clears the validators, evals the block, runs validate" do
      expect(built).to receive(:clear_validators!)

      begin
        SmashTheState::Operation::State.eval_validation_directives_block(instance) do
          validates_presence_of :bread
        end
      rescue SmashTheState::Operation::State::Invalid => e
        expect(e.state.errors[:bread]).to include("can't be blank")
      end
    end

    context "when validate returns true" do
      let!(:instance) { built.new(bread: "rye") }

      it "returns the state" do
        state = SmashTheState::Operation::State.eval_validation_directives_block(instance) do
          validates_presence_of :bread
        end

        expect(state.bread).to eq(state.bread)
      end
    end
  end

  describe "#eval_custom_validator_block" do
    let!(:built) do
      subject.build do
        attribute :bread, :string
      end
    end

    let!(:instance) { built.new }

    it "instance_evals the block" do
      begin
        SmashTheState::Operation::State.eval_custom_validator_block(instance) do |i|
          i.errors.add(:bread, "is moldy")
        end
      rescue SmashTheState::Operation::State::Invalid => e
        expect(e.state.errors[:bread]).to include("is moldy")
      end
    end

    context "with no errors present" do
      it "returns the state" do
        state = SmashTheState::Operation::State.eval_custom_validator_block(instance) do
          :noop
        end

        expect(state).to eq(instance)
      end
    end
  end
end
