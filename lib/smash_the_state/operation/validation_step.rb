module SmashTheState
  class Operation
    class ValidationStep < Step
      attr_reader :implementations

      def initialize(options = {})
        @name            = :validate
        @implementations = []
        @options         = {
          side_effect_free: true
        }.merge(options)
      end

      def add_implementation(&block)
        tap do |s|
          @implementations << block
        end
      end

      def implementation
        blocks = @implementations

        Proc.new do
          # self here should be a state
          blocks.reduce(self) do |memo, i|
            memo.class_eval(&i)
          end
        end
      end

      def validate!(state)
        state.tap do
          SmashTheState::Operation::State.
            eval_validation_directives_block(state, &implementation)
        end
      end
    end
  end
end
