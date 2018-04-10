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
        klass.step :change_state_to_something_else do |_state|
          :something_else
        end

        klass.step :change_state_to_something_else do |state, original_state|
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

  describe "self#dry_run_for_step" do
    context "with a step that is not dry_run_safe" do
      before do
        klass.step :step_one do |state|
          state.name = state.name + " foo"
          state
        end

        klass.dry_run_for_step :step_one do |state|
          state.name = state.name + " bar"
          state
        end
      end

      it "defines a dry_run_safe step with a _dry_run_safe suffix" do
        step = klass.sequence.steps.last
        expect(step.name).to eq(:step_one_dry_run_safe)
        expect(step.dry_run_safe?).to eq(true)
      end

      context "called in a dry run" do
        it "runs the alternative but not the normal step" do
          expect(klass.dry_run(name: "zip").name).to eq("zip bar")
        end
      end

      context "called not in a dry run" do
        it "runs the normal but not the alternative step" do
          expect(klass.call(name: "zip").name).to eq("zip foo")
        end
      end
    end

    context "with a step that is dry_run_safe" do
      before do
        klass.step :step_one, dry_run_safe: true do |_state|
          :step_one
        end
      end

      it "raises an exception" do
        begin
          klass.dry_run_for_step :step_one do
          end
        rescue => e
          expect(e.to_s).to include("it is already dry run safe")
        end
      end
    end

    context "with no matching step" do
      it "raises an exception" do
        begin
          klass.dry_run_for_step :step_one do
          end
        rescue => e
          expect(
            e.to_s
          ).to include("a dry run alternative was provided for undefined step")
        end
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
       "dry run safe, that skips non-dry_run_safe? steps" do
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

        klass.step :safe, dry_run_safe: true do |state|
          state.name = state.name + " are nice"
          state
        end
      end

      it "runs all the steps up to and including validation, plus any " \
         "further steps marked dry_run_safe" do
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
        klass.step :run_this, dry_run_safe: true do |state|
          state.name = state.name + " People"
          state
        end

        klass.step :skip_this do |_state|
          raise "should not hit this"
        end
      end

      it "returns the state produced by the dry_run_safe? steps" do
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

    it "adds a representer step, marked as dry_run_safe, which returns a " \
       "representer initialized with the state" do
      expect(representer).to receive(:represent).and_call_original
      represented = klass.call(params)
      expect(represented).to be_a(representer)
      expect(represented.state.name).to eq("zeus")

      step = klass.sequence.steps.find { |s| s.name == :represent }
      expect(step.dry_run_safe?).to eq(true)
    end
  end

  describe "#continues_from" do
    context "with a state class" do
      let!(:continuing_operation) do
        Class.new(SmashTheState::Operation).tap do |k1|
          k1.class_eval do
            prelude_klass = Class.new(SmashTheState::Operation).tap do |k2|
              k2.class_eval do
                schema do
                  attribute :name, :string
                  attribute :age, :integer
                end

                step :prelude_step do |state|
                  state.name = "Peter"
                  state
                end
              end
            end

            continues_from prelude_klass

            step :extra_step do |state|
              state.age = 166
              state
            end
          end
        end
      end

      it "continues from the prelude operation" do
        result = continuing_operation.call({})
        expect(result.name).to eq("Peter")
        expect(result.age).to eq(166)
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
