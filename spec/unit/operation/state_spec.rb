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

  describe "self#schema" do
    jam_definition = Class.new(SmashTheState::Operation::Definition).tap do |k|
      k.class_eval do
        definition "Jam"

        schema do
          attribute :sweetened, :boolean
        end
      end
    end

    let!(:built) do
      subject.build do
        schema :bread do
          attribute :loaves, :integer

          # inline
          schema :butter do
            attribute :salted, :boolean
          end

          # by reference
          schema :jam, ref: jam_definition
        end
      end
    end

    let!(:instance) do
      built.new(
        bread: {
          loaves: 3,
          butter: {
            salted: true
          },
          jam: {
            sweetened: false
          }
        }
      )
    end

    it "allows for inline nesting of schemas" do
      expect(instance.bread.loaves).to eq(3)
      expect(instance.bread.butter.salted).to eq(true)
    end

    it "allows for reference of type definitions" do
      expect(instance.bread.jam.sweetened).to eq(false)
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

    it "calls the block" do
      SmashTheState::Operation::State.eval_custom_validator_block(instance) do |i|
        i.errors.add(:bread, "is moldy")
      end
    rescue SmashTheState::Operation::State::Invalid => e
      expect(e.state.errors[:bread]).to include("is moldy")
    end

    it "only raises an error for the current state" do
      state = SmashTheState::Operation::State.
                eval_custom_validator_block(instance, built.new) do |_i, original_state|
        original_state.errors.add(:bread, "is moldy")
      end

      expect(state).to eq(instance)
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

  describe "self#model_name" do
    context "when provided with a model name" do
      let!(:built) do
        subject.build do
          model_name "Foo"
        end
      end

      it "uses the provided model name" do
        expect(built.model_name.to_s).to eq("Foo")
      end
    end

    context "when not provided a model name" do
      let!(:built) do
        subject.build {}
      end

      it "uses the default model name of 'State'" do
        expect(built.model_name.to_s).to eq("State")
      end
    end
  end
end
