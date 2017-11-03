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
          i.add_step(:one) do |state|
            state << :error
            raise SmashTheState::Operation::Error, state
          end
        end

        instance.add_step(:two) do |_state|
          raise "should not hit this"
        end
      end

      context "with an error handler" do
        before do
          instance.add_error_handler_for_step :one do |state|
            state << :handled
          end
        end

        it "runs the error handler" do
          expect(instance.call([])).to eq([:error, :handled])
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
        expect(step.implementation.call([:existing])).to eq([:existing, :step_added])
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

  describe "#middleware_class" do
    let!(:instance) { subject.new }

    before do
      instance.middleware_class_block = proc do |state|
        state.to_s
      end
    end

    context "with a middleware_class_block" do
      it "runs the middleware_class_block, passes in the state, constantizes" do
        expect(instance.middleware_class("String")).to eq(String)
      end
    end

    context "with a NameError" do
      it "returns nil" do
        expect(instance.middleware_class("Whazzat")).to eq(nil)
      end
    end

    context "with a NoMethodError" do
      let!(:state) { double }

      before do
        allow(state).to receive(:to_s) do
          raise NoMethodError
        end
      end

      it "returns nil" do
        expect(instance.middleware_class(state)).to eq(nil)
      end
    end
  end

  describe "#add_middleware_step" do
    let!(:instance) { subject.new }

    context "with a middleware class defined" do
      before do
        instance.middleware_class_block = proc do |_state|
          "JSON"
        end

        instance.add_middleware_step :parse
      end

      it "delegates the step to the middleware class" do
        expect(instance.call('{"foo":"bar"}')).to eq("foo" => "bar")
      end
    end

    context "with no middleware class defined" do
      it "just returns the state" do
        expect(instance.call('{"foo":"bar"}')).to eq('{"foo":"bar"}')
      end
    end
  end
end
