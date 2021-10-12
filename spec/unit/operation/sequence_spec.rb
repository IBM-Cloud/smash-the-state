require "spec_helper"
require "json"

describe SmashTheState::Operation::Sequence do
  let!(:subject) { SmashTheState::Operation::Sequence }

  describe "#initialize" do
    it "initializes steps as an array" do
      expect(subject.new.steps).to be_a(Array)
    end
  end

  describe "#call" do
    let!(:instance) { subject.new }

    context "in general" do
      before do
        instance.add_step(:one) do |state|
          state << 1
        end

        instance.add_step(:two) do |state|
          state << 2
        end
      end

      it "runs each steps' implementation block, passing each steps' return " \
         "value to the next step" do
        expect(instance.call([])).to eq([1, 2])
      end
    end

    context "with an Invalid exception" do
      before do
        instance.instance_eval do |i|
          i.add_step(:one) do |state|
            state << :invalid
            raise SmashTheState::Operation::State::Invalid, state
          end
        end

        instance.add_step(:two) do |_state|
          raise "should not hit this"
        end
      end

      it "returns the state of the step, skips subsequent steps" do
        expect(instance.call([])).to eq([:invalid])
      end
    end

    context "with an Error exception" do
      before do
        instance.instance_eval do |i|
          i.add_step(:one) do |_state|
            # test that we can pass a different state to the error handler
            raise SmashTheState::Operation::Error, :custom_state
          end
        end

        instance.add_step(:two) do |_state|
          raise "should not hit this"
        end
      end

      context "with an error handler" do
        before do
          instance.add_error_handler_for_step :one do |custom_state, original_state|
            [custom_state, original_state]
          end
        end

        it "runs the error handler" do
          expect(instance.call([])).to eq([:custom_state, []])
        end
      end

      context "without an error handler" do
        it "re-raises the Error exception" do
          expect do
            begin
              instance.call([])
              raise "should not hit this"
            rescue SmashTheState::Operation::Error => e
              expect(e.state).to eq([:foo])
            end
          end
        end
      end
    end
  end

  describe "steps" do
    let!(:instance) { subject.new }

    before do
      instance.add_step :new_step do |state|
        state << :step_added
      end
    end

    let!(:step) { instance.steps.first }

    describe "#add_step" do
      it "adds a Step instance with the step name and block" do
        expect(instance.steps.length).to eq(1)
        expect(step).to be_a(SmashTheState::Operation::Step)
        expect(step.name).to eq(:new_step)
        expect(step.implementation.call(%i[existing])).to eq(%i[existing step_added])
      end
    end

    describe "#add_error_handler_for_step" do
      before do
        instance.add_error_handler_for_step :new_step do |state|
          state.tap do
            state << :handled
          end
        end
      end

      it "the error handler block is added to the named step" do
        expect(step.error_handler.call([])).to eq([:handled])
      end

      context "error handlers for missing steps do nothing" do
        before do
          instance.add_error_handler_for_step :not_there do |_state|
            raise "nope"
          end
        end

        it "is allowed but does nothing" do
          expect(instance.steps.map(&:name)).to eq([:new_step])
        end
      end
    end
  end

  describe "#override_step" do
    let!(:instance) { subject.new }

    before do
      instance.add_step :one do |state|
        state << :one
      end

      instance.add_step :two do |state|
        state << :two
      end

      instance.add_step :three do |state|
        state << :three
      end
    end

    context "when no step by the given name exists" do
      it "raises an exception" do
        begin
          instance.override_step :four do
          end

          raise "should not reach this"
        rescue SmashTheState::Operation::Sequence::BadOverride => e
          expect(
            e.to_s
          ).to eq("overriding step :four failed because it does not exist")
        end
      end
    end

    context "with a pre-existing step by that name" do
      it "replaces the step in the position in which it originally appeared" do
        instance.override_step :two do |state|
          state << :pants
        end

        expect(instance.call([])).to eq(%i[one pants three])
      end
    end
  end

  describe "#add_validation_step" do
    let!(:instance) { subject.new }
    let!(:implementations) { 3.times.map { -> {} } }

    before do
      implementations.each { |i| instance.add_validation_step(&i) }
    end

    it "adds all the validation implementations to the validate step" do
      validate_step = instance.steps_for_name(:validate).first
      expect(validate_step.implementations).to eq(implementations)
    end
  end

  describe "#middleware_class" do
    let!(:instance) { subject.new }

    before do
      instance.middleware_class_block = proc do |state|
        state.to_s
      end
    end

    context "with a middleware_class_block" do
      context "that returns a string" do
        it "runs the middleware_class_block, passes in the state, constantizes" do
          expect(instance.middleware_class("String")).to eq(String)
        end
      end

      context "that returns a constant" do
        before do
          instance.middleware_class_block = proc do |state|
            state
          end
        end

        context "that is a class" do
          let!(:klass) { Class.new }

          it "runs the middleware_class_block, passes in the state" do
            expect(instance.middleware_class(klass)).to eq(klass)
          end
        end

        context "that returns a module" do
          let!(:modyule) { Module.new }

          it "runs the middleware_class_block, passes in the state" do
            expect(instance.middleware_class(modyule)).to eq(modyule)
          end
        end
      end
    end

    context "with a NameError" do
      it "returns nil" do
        expect(instance.middleware_class("Whazzat")).to eq(nil)
      end
    end
  end

  describe "#add_middleware_step" do
    let!(:instance) { subject.new }

    context "with a middleware class defined" do
      let!(:middleware_class) do
        class SequenceSpecMiddleware
          def self.extra_step(state, original_state)
            state.merge(original_state)
          end
        end
      end

      before do
        instance.middleware_class_block = proc do |_state, _original_state|
          "SequenceSpecMiddleware"
        end

        instance.add_step :inline_step do |_state|
          { baz: "bing" }
        end

        instance.add_middleware_step :extra_step
      end

      it "block receives both the state and frozen original state" do
        instance.middleware_class_block = proc do |state, original_state|
          expect(state).to eq(baz: "bing")
          expect(original_state).to eq(foo: "bar")
          expect(original_state.frozen?).to eq(true)
        end

        instance.call(foo: "bar")
      end

      it "delegates the step to the middleware class" do
        expect(instance.call(foo: "bar")).to eq(baz: "bing", foo: "bar")
      end
    end

    context "with no middleware class defined" do
      it "just returns the state" do
        expect(instance.call(foo: "bar")).to eq(foo: "bar")
      end
    end
  end

  describe "#slice" do
    let!(:instance) { subject.new }

    before do
      instance.add_step(:one) do |state|
        state << 1
      end

      instance.add_step(:two) do |state|
        state << 2
      end

      instance.add_step(:three) do |state|
        state << 3
      end

      instance.add_step(:four) do |state|
        state << 4
      end

      instance.add_step(:five) do |state|
        state << 5
      end
    end

    it "returns a new sequence cut to the specified length from the " \
       "specified start" do
      sliced = instance.slice(1, 3)
      expect(sliced.steps.map(&:name)).to eq(%i[two three four])

      # doesn't mutate the original
      expect(instance.steps.length).to eq(5)
      expect(instance.object_id).to_not eq(sliced.object_id)
    end
  end
end
