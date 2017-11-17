require_relative 'operation/error'
require_relative 'operation/sequence'
require_relative 'operation/step'
require_relative 'operation/swagger'
require_relative 'operation/state'

module SmashTheState
  class Operation
    class << self
      attr_reader :state_class

      delegate :eval_swagger_params,
               :override_swagger_param,
               :override_swagger_params,
               to: :state_class

      # Runs the operation, creating the state based on the provided params,
      # passing it from step to step and returning the last step.
      def call(params = {})
        state = state_class.new(params)
        sequence.call(state)
      end

      def schema(&block)
        @state_class = Operation::State.build(&block)
      end

      def step(step_name, &block)
        sequence.add_step(step_name, &block)
      end

      def error(*steps, &block)
        steps.each do |step_name|
          sequence.add_error_handler_for_step(step_name, &block)
        end
      end

      def policy(klass, method_name)
        step :policy do |state|
          klass.new(state.current_user, state).send(method_name) ||
            raise(NotAuthorized, state)
        end
      end

      def middleware_class(&block)
        sequence.middleware_class_block = block
      end

      def middleware_step(step_name)
        sequence.add_middleware_step(step_name)
      end

      def validate(&block)
        step :validate do |state|
          Operation::State.eval_validation_directives_block(state, &block)
        end
      end

      def custom_validation(&block)
        step :validate do |state|
          Operation::State.eval_custom_validator_block(state, &block)
        end
      end

      def represent(representer)
        step :represent do |state|
          representer.new(state)
        end
      end

      private

      def sequence
        @sequence ||= Operation::Sequence.new
      end

      def error!(state)
        raise Error, state
      end
    end
  end
end
