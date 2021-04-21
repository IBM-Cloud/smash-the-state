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

  describe "with no defined schema" do
    let!(:params) { double }
    let!(:klass) do
      Class.new(SmashTheState::Operation)
    end

    let!(:sequence) { klass.send(:sequence) }

    it "passes in the raw params as the initial state" do
      expect(sequence).to receive(:call).with(params)
      klass.call(params)
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
      klass.step :first_name, community: true do |state|
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

    describe "original state" do
      before do
        klass.step :change_state_to_something_else1 do |_state|
          :something_else
        end

        klass.step :change_state_to_something_else2 do |state, original_state|
          # state should be changed by the previous step
          raise "should not hit this" unless state == :something_else

          # and switch the state back to the original state, which should be
          # available via the second argument to the block
          original_state
        end
      end

      it "is always available in each step as the second argument passed " \
         "into the step block" do
        state = klass.call(age: 148)
        expect(state.name).to eq(nil)
        expect(state.age).to eq(148)
      end

      it "sets the options on the step" do
        expect(klass.sequence.steps.first.options[:community]).to eq(true)
      end
    end
  end

  describe "self#override_step" do
    let!(:step_name) { :override_me }
    let!(:step_options) { { some: :option } }
    let!(:implementation) do
      proc do
        :success
      end
    end
    let!(:token_result) { double }

    it "delegates to the sequence implementation of :override_step" do
      expect(
        klass.sequence
      ).to receive(:override_step).with(
        step_name,
        step_options,
        &implementation
      )

      klass.override_step(step_name, step_options, &implementation)
    end
  end

  describe "inheritance" do
    let!(:parent) do
      Class.new(SmashTheState::Operation).tap do |k|
        k.class_eval do
          schema do
            attribute :countup, :string
          end

          validate do
            validates_presence_of :countup
          end

          step :one do |state|
            state.countup += "one"
            state
          end

          step :two do |state|
            state.countup += "two"
            state
          end

          dry_run_sequence do
            step :one
            step :two
            step :three do |state|
              state.countup += "blar"
              state
            end
          end
        end
      end
    end

    let!(:child) do
      Class.new(parent).tap do |k|
        k.class_eval do
          override_step :two do |state|
            state.countup += "oneandahalf"
            state
          end

          validate do
            validates_length_of :countup, maximum: 5
          end

          step :three do |state|
            state.countup += "three"
            state
          end
        end
      end
    end

    it "duplicates steps from the parent operation, allows overrides" do
      expect(parent.sequence.steps.length).to eq(3)
      expect(child.sequence.steps.length).to eq(4)
      expect(child.call(countup: "zero").countup).to eq("zerooneoneandahalfthree")
    end

    it "duplicates the state class from the parent operation" do
      expect(child.state_class).to_not eq(parent.state_class)
      expect(child.state_class.attributes_registry).to eq(countup: [:string, {}])
    end

    it "merges the validation blocks" do
      too_large = child.call(countup: "thisistoolarge")
      expect(too_large.errors[:countup]).to eq(["is too long (maximum is 5 characters)"])

      too_large = child.call(countup: "")
      expect(too_large.errors[:countup]).to eq(["can't be blank"])
    end

    it "populates the dry run sequence and honors overridden steps" do
      expect(child.dry_run(countup: "zero").countup).to eq("zerooneoneandahalfblar")
    end
  end

  describe "self#dynamic_schema" do
    let!(:klass) do
      Class.new(SmashTheState::Operation).tap do |k|
        k.class_eval do
          dynamic_schema do |params|
            attribute "#{params[:adjective]}_#{params[:animal]}", :string
          end

          step :step_one do |state|
            state.fat_ocelot = "maybe"
            state
          end

          step :step_two do |state, original_state|
            [state, original_state]
          end
        end
      end
    end

    it "produces an 'inline' schema that is evaluated each time the operation "\
       "runs while passing the 'original' dynamic state onto the next step" do
      state, original_state = klass.call(adjective: "fat", animal: "ocelot", fat_ocelot: "no")

      expect(state.fat_ocelot).to eq("maybe")
      expect(original_state.fat_ocelot).to eq("no")
    end
  end

  describe "self#dry_run_sequence" do
    context "with a custom dry run sequence block" do
      before do
        klass.step :step_one do |state|
          state.name = state.name + " one"
          state
        end

        klass.step :step_two do |state|
          state.name = state.name + " two"
          state
        end

        klass.step :step_three do |state|
          state.name = state.name + " three"
          state
        end

        klass.dry_run_sequence do
          # we'll reference this step
          step :step_one

          # we'll provide a custom implementation of this step
          step :step_two do |state|
            state.name = state.name + " custom"
            state
          end

          # and step three will be just be omitted
        end
      end

      it "provides a custom sequence for the dry run that " \
         "contains only side-effect free steps" do
        result = klass.call(name: "Sam")
        expect(result.name).to eq("Sam one two three")

        expect(
          klass.dry_run_sequence.steps.all?(&:side_effect_free?)
        ).to eq(true)

        dry_result = klass.dry_run(name: "Sam")
        expect(dry_result.name).to eq("Sam one custom")
      end
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

  describe "self#policy" do
    let!(:current_user) { Struct.new(:age).new(64) }

    before do
      policy_klass = Class.new.tap do |k|
        k.class_eval do
          attr_reader :user, :state

          def initialize(user, state)
            @user  = user
            @state = state
          end

          def allowed?
            @user.age > 21
          end
        end
      end

      klass.class_eval do
        policy policy_klass, :allowed?

        # we should receive the state from the policy test
        step :was_allowed do |state|
          state.tap do
            state.name = "allowed"
          end
        end
      end

      @policy_klass = policy_klass
    end

    context "when the policy permits" do
      it "newifies the policy class with the state, runs the method" do
        state = klass.call(current_user: current_user)
        expect(state.name).to eq("allowed")
      end
    end

    context "when the policy forbids" do
      before do
        current_user.age = 3
      end

      it "raises an exception, embeds the policy instance" do
        begin
          klass.call(current_user: current_user)
          raise "should not hit this"
        rescue SmashTheState::Operation::NotAuthorized => e
          expect(e.policy_instance).to be_a(@policy_klass)
          expect(e.policy_instance.user).to eq(current_user)
        end
      end
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
    let!(:step_options) { { foo: :bar } }

    it "delegates to sequence#add_middleware_step" do
      expect(sequence).to receive(:add_middleware_step).with(step_name, step_options)
      klass.middleware_step :means_of_production, step_options
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

    it "adds a validation step with the specified block, marked as " \
       "side-effect free, that skips steps with side-effects" do
      state = klass.call(name: nil)
      expect(state.errors[:name]).to include("can't be blank")
      expect(
        klass.sequence.steps_for_name(:validate).all?(&:side_effect_free?)
      ).to be true
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

  describe "#dry_run" do
    context "with a validation step" do
      before do
        klass.step :run_this do |state|
          state.name = state.name + " People"
          state
        end

        klass.validate do |_state|
          validates_presence_of :name
          validates_presence_of :age
        end

        klass.step :skip_this do |_state|
          raise "should not hit this"
        end

        klass.step :safe, side_effect_free: true do |state|
          state.name = state.name + " are nice"
          state
        end
      end

      it "runs all the steps up to and including validation, plus any " \
         "further steps marked side-effect free" do
        result = klass.dry_run(name: "Snake")
        expect(result.name).to eq("Snake People")
        expect(result.errors[:name]).to be_empty
        expect(result.errors[:age]).to eq(["can't be blank"])

        result = klass.dry_run(name: "Snake", age: 35)
        expect(result.name).to eq("Snake People are nice")
      end
    end

    context "with no validation step" do
      before do
        klass.step :run_this, side_effect_free: true do |state|
          state.name = state.name + " People"
          state
        end

        klass.step :skip_this do |_state|
          raise "should not hit this"
        end
      end

      it "returns the state produced by the side-effect free steps" do
        result = klass.dry_call(name: "Snake")
        expect(result.name).to eq("Snake People")
        expect(result.errors).to be_empty
      end
    end
  end

  describe "#represent" do
    let!(:representer) do
      Class.new.tap do |k|
        k.class_eval do
          attr_reader :state

          def self.represent(state)
            new(state)
          end

          def initialize(state)
            @state = state
          end
        end
      end
    end

    let!(:params) { { name: "zeus" } }

    before do
      klass.represent representer
    end

    it "adds a representer step, marked as side-effect free, which returns a " \
       "representer initialized with the state" do
      expect(representer).to receive(:represent).and_call_original
      represented = klass.call(params)
      expect(represented).to be_a(representer)
      expect(represented.state.name).to eq("zeus")

      step = klass.sequence.steps.find { |s| s.name == :represent }
      expect(step.side_effect_free?).to eq(true)
    end

    describe "represent_with spec helper" do
      it "matches" do
        allow_any_instance_of(String).to receive(:as_json) do |string|
          string
        end

        expect(klass).to represent_with representer
      end
    end

    describe "represent_collection_with spec helper" do
      it "matches" do
        allow_any_instance_of(String).to receive(:as_json) do |string|
          string
        end

        expect(klass).to represent_collection_with representer
      end
    end

    describe "represent_collection spec helper" do
      it "matches" do
        allow_any_instance_of(String).to receive(:as_json) do |string|
          { string => string }
        end

        expect(klass).to represent_collection "representation", with: representer
      end
    end
  end

  describe "#continues_from" do
    context "with a state class" do
      let!(:continuing_operation) do
        Class.new(SmashTheState::Operation).tap do |k1|
          k1.class_eval do
            @prelude_klass = Class.new(SmashTheState::Operation).tap do |k2|
              k2.class_eval do
                schema do
                  attribute :name, :string
                  attribute :age, :integer
                end

                step :prelude_step do |state|
                  state.name = "Peter"
                  state
                end

                dry_run_sequence do
                  step :prelude_step
                end
              end
            end

            continues_from @prelude_klass

            step :extra_step do |state|
              state.age = 166
              state
            end

            dry_run_sequence do
              step :extra_step
            end
          end
        end
      end

      let!(:prelude) do
        continuing_operation.instance_variable_get(:@prelude_klass)
      end

      it "continues from the prelude operation" do
        result = continuing_operation.call({})
        expect(result.name).to eq("Peter")
        expect(result.age).to eq(166)

        steps = continuing_operation.dry_run_sequence.steps.map(&:implementation)
        prelude_steps = prelude.dry_run_sequence.steps.map(&:implementation)
        expect(steps & prelude_steps).to eq(prelude_steps)
      end

      describe "continues_from spec helper" do
        it "matches" do
          expect(continuing_operation).to continue_from prelude
        end
      end
    end

    context "with a nil state class" do
      it "doesn't try to dup a nil state class" do
        op = Class.new(SmashTheState::Operation).tap do |k1|
          k1.class_eval do
            prelude_klass = Class.new(SmashTheState::Operation)
            continues_from prelude_klass
          end
        end

        expect(op).to be_truthy
      end
    end
  end
end
