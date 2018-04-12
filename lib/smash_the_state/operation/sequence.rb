module SmashTheState
  class Operation
    class Sequence
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
          seq.run_options[:dry] = true
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
        @steps << Step.new(step_name, options, &block)
      end

      def step_for_name(name)
        steps.find { |s| s.name == name }
      end

      def add_error_handler_for_step(step_name, &block)
        step = @steps.find { |s| s.name == step_name }

        # should we raise an exception instead?
        return if step.nil?

        step.error_handler = block
      end

      def middleware_class(state)
        middleware_class_block.call(state).constantize
      rescue NameError, NoMethodError
        nil
      end

      def add_middleware_step(step_name, options = {})
        step = Operation::Step.new step_name, options do |state|
          if middleware_class(state).nil?
            # no-op
            state
          else
            middleware_class(state).send(step_name, state)
          end
        end

        @steps << step
      end

      private

      def run_steps(steps_to_run, state)
        # retain a copy of the original state so that we can refer to it for posterity as
        # the operation state gets mutated over time
        original_state = state.dup
        current_step = nil

        steps_to_run.reduce(state) do |memo, step|
          current_step = step

          # we're gonna pass the state from the previous step into the implementation as
          # 'memo', but for convenience, we'll also always pass the original state into
          # the implementation as 'original_state' so that no matter what you can get to
          # your original input
          step.implementation.call(memo, original_state, run_options)
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
