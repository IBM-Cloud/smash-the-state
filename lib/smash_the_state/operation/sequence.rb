module SmashTheState
  class Operation
    class Sequence
      attr_accessor :middleware_class_block
      attr_reader :steps

      def initialize
        @steps = []
      end

      def call(state)
        current_step = nil

        @steps.reduce(state) do |memo, step|
          current_step = step
          step.implementation.call(memo)
        end
      rescue Operation::State::Invalid => e
        e.state
      rescue Operation::Error => e
        raise e if current_step.error_handler.nil?
        current_step.error_handler.call(state)
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
            state.tap do
              middleware_class(state).send(step_name, state)
            end
          end
        end

        @steps << step
      end
    end
  end
end
