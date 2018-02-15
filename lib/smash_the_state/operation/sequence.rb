module SmashTheState
  class Operation
    class Sequence
      attr_accessor :middleware_class_block
      attr_reader :steps

      def initialize
        @steps = []
      end

      def call(state)
        # retain a copy of the original state so that we can refer to it for posterity as
        # the operation state gets mutated over time
        original_state = state.dup
        current_step = nil

        @steps.reduce(state) do |memo, step|
          current_step = step

          # we're gonna pass the state from the previous step into the implementation as
          # 'memo', but for convenience, we'll also always pass the original state into
          # the implementation as 'original_state' so that no matter what you can get to
          # your original input
          step.implementation.call(memo, original_state)
        end
      rescue Operation::State::Invalid => e
        e.state
      rescue Operation::Error => e
        raise e if current_step.error_handler.nil?
        current_step.error_handler.call(e.state, original_state)
      end

      def add_step(step_name, &block)
        @steps << Step.new(step_name, &block)
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

      def add_middleware_step(step_name)
        step = Operation::Step.new step_name do |state|
          if middleware_class(state).nil?
            # no-op
            state
          else
            middleware_class(state).send(step_name, state)
          end
        end

        @steps << step
      end
    end
  end
end
