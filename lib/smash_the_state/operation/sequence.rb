module SmashTheState
  class Operation
    class Sequence
      class BadOverride < StandardError; end
      class StepConflict < StandardError; end

      attr_accessor :middleware_class_block
      attr_reader :steps, :run_options

      def initialize
        @steps = []
        @run_options = { dry: false }
      end

      def call(state)
        run_steps(@steps, state)
      end

      def slice(start, count)
        # slice should return a copy of the object being sliced
        dup.tap do |seq|
          # we're going to slice the steps, which is really the meat of a sequence, but we
          # need to evaluate in the copy context so that we can swap out the steps for a
          # new copy of steps (because note - even though we've copied the sequence
          # already, the steps of the copy still refer to the steps of the original!)
          seq.instance_eval do
            @steps = seq.steps.slice(start, count)
          end
        end
      end

      # return a copy without the steps that produce side-effects
      def side_effect_free
        dup.tap do |seq|
          seq.instance_eval do
            @steps = seq.steps.select(&:side_effect_free?)
          end
        end
      end

      # marks all the the currently defined steps as free of side-effects
      def mark_as_side_effect_free!
        steps.each { |s| s.options[:side_effect_free] = true }
      end

      def add_step(step_name, options = {}, &block)
        # steps need to be unique
        unless steps_for_name(step_name).empty?
          raise(
            StepConflict,
            "an operation step named #{step_name.inspect} already exists"
          )
        end

        @steps << Step.new(step_name, options, &block)
      end

      def add_validation_step(options = {}, &block)
        step = steps_for_name(:validate).first ||
               SmashTheState::Operation::ValidationStep.new(options)

        step.add_implementation(&block)
        @steps |= [step]
      end

      def override_step(step_name, options = {}, &block)
        step = steps_for_name(step_name).first

        if step.nil?
          raise(
            BadOverride,
            "overriding step #{step_name.inspect} failed because it does " \
            "not exist"
          )
        end

        @steps[@steps.index(step)] = Step.new(step_name, options, &block)
      end

      # returns steps named the specified name. it's generally bad form to have mulitple
      # steps with the same name, but it can happen in some reasonable cases (the most
      # common being :validate)
      def steps_for_name(name)
        steps.select { |s| s.name == name }
      end

      def add_error_handler_for_step(step_name, &block)
        step = @steps.find { |s| s.name == step_name }

        # should we raise an exception instead?
        return if step.nil?

        step.error_handler = block
      end

      def middleware_class(state, original_state = nil)
        klass = middleware_class_block.call(state, original_state)

        case klass
        when Module, Class
          klass
        else
          begin
            klass.constantize if klass.respond_to?(:constantize)
          rescue NameError
            nil
          end
        end
      end

      def add_middleware_step(step_name, options = {})
        step = Operation::Step.new step_name, options do |state, original_state|
          if middleware_class(state, original_state).nil?
            # no-op
            state
          else
            middleware_class(state, original_state).send(step_name, state, original_state)
          end
        end

        @steps << step
      end

      def dynamic_schema?
        dynamic_schema_step.nil? == false
      end

      def dynamic_schema_step
        steps_for_name(:_dynamic_schema).first
      end

      private

      def make_original_state(state)
        return dynamic_schema_step.implementation.call(state, state, run_options) if dynamic_schema?

        state.dup
      end

      def run_steps(steps_to_run, state)
        # retain a copy of the original state so that we can refer to it for posterity as
        # the operation state gets mutated over time
        original_state = make_original_state(state)
        current_step = nil

        steps_to_run.reduce(state) do |memo, s|
          current_step = s

          # we're gonna pass the state from the previous step into the implementation as
          # 'memo', but for convenience, we'll also always pass the original state into
          # the implementation as 'original_state' so that no matter what you can get to
          # your original input
          if s.name == :validate
            s.validate!(memo)
          else
            s.implementation.call(memo, original_state, run_options)
          end
        end
      rescue Operation::State::Invalid => e
        e.state
      rescue Operation::Error => e
        raise e if current_step.error_handler.nil?

        current_step.error_handler.call(e.state, original_state)
      end
    end
  end
end
