require 'spec_helper'

describe SmashTheState::Operation do
  let!(:klass) do
    Class.new(SmashTheState::Operation).tap do |k|
      k.class_eval do
        schema do
          attribute :name, :string
          attribute :age,  :integer
        end
      end
    end
  end

  describe "#self.call" do
    let!(:sequence) { klass.send(:sequence) }

    it "passes a new state class instance to the sequence, returning the result" do
      expect(sequence).to receive(:call) do |state|
        @state = state
        :result
      end

      result = klass.call({})
      expect(result).to eq(:result)
    end
  end

  describe "#self.schema" do
    before do
      klass.schema do
        attribute :food, :string
      end
    end

    it "sets the state_class an Operation::State-derived class with the evaluated block" do
      expect(klass.state_class.attributes_registry).to eq(food: [:string, {}])
    end
  end

  describe "#self.step" do
    before do
      klass.step :first_name do |state|
        state.tap do
          state.name = "Emma"
        end
      end

      klass.step :last_name do |state|
        state.tap do
          state.name.concat(" Goldman")
        end
      end
    end

    it "adds a step that is handed the previous state and hands the return " \
       "value to the next step" do
      state = klass.call(age: 148)
      expect(state.name).to eq("Emma Goldman")
      expect(state.age).to eq(148)
    end
  end

  describe "self#error" do
    before do
      klass.class_eval do |k|
        k.step :what_about_roads do |state|
          if state.name == "broken roads"
            error!(state)
          else
            state
          end
        end
      end

      klass.error :what_about_roads do |state|
        state.tap do
          state.name = "working roads"
        end
      end
    end

    it "adds an error handler to the specified step(s)" do
      state = klass.call(name: "broken roads")
      expect(state.name).to eq("working roads")
    end
  end

  describe "self#middleware_class" do
    let!(:sequence) { klass.send(:sequence) }

    before do
      klass.middleware_class do |state|
        "#{state.name.camelize}::Class"
      end
    end

    it "sets the middleware class block on the sequence" do
      string_class = sequence.middleware_class_block.call(
        Struct.new(:name).new("working")
      )

      expect(string_class).to eq("Working::Class")
    end
  end

  describe "self#middleware_step" do
    let!(:sequence) { klass.send(:sequence) }
    let!(:step_name) { :means_of_production }

    it "delegates to sequence#add_middleware_step" do
      expect(sequence).to receive(:add_middleware_step).with(step_name)
      klass.middleware_step :means_of_production
    end
  end

  describe "#validate" do
    before do
      klass.validate do |_state|
        validates_presence_of :name
      end

      klass.step :skip_this do |_state|
        raise "should not hit this"
      end
    end

    it "adds a validation step with the specified block, skips subsequent steps" do
      state = klass.call(name: nil)
      expect(state.errors[:name]).to include("can't be blank")
    end
  end

  describe "#custom_validation" do
    before do
      klass.custom_validation do |state|
        state.errors.add(:name, "no gods") if state.name == "zeus"
      end

      klass.step :skip_this do |_state|
        raise "should not hit this"
      end
    end

    it "adds a custom validation step with the specified block, skips subsequent steps" do
      state = klass.call(name: "zeus")
      expect(state.errors[:name]).to include("no gods")
    end
  end
end
