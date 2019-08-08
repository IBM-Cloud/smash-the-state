module SmashTheState
  class Operation
    class ValidationStep < Step
      attr_accessor :implementations

      def initialize(options = {})
        @name            = :validate
        @implementations = []
        @options         = {
          side_effect_free: true
        }.merge(options)
      end

      def add_implementation(&block)
        tap do
          @implementations << block
        end
      end

      def implementation
        blocks = @implementations

        proc do
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

      def dup
        # it's not enough to duplicate the step, we should also duplicate our
        # implementations. otherwise the list of implementations will be shared
        super.tap do |s|
          s.implementations = s.implementations.dup
        end
      end
    end
  end
end
