require_relative 'operation/error'
require_relative 'operation/sequence'
require_relative 'operation/step'
require_relative 'operation/state'
require_relative 'operation/dry_run'
require_relative 'operation/state_type'
require_relative 'operation/definition'

module SmashTheState
  class Operation
    extend DryRun

    class << self
      attr_reader :state_class

      # Runs the operation, creating the state based on the provided params,
      # passing it from step to step and returning the last step.
      def call(params = {})
        run_sequence(sequence, params)
      end
      alias run call

      # inheritance doesn't work with class attr_readers, this method is provided to
      # bootstrap an operation as a continuation of a "prelude" operation
      def continues_from(prelude)
        @state_class = prelude.state_class && prelude.state_class.dup
        sequence.steps.concat prelude.sequence.steps
      end

      def schema(&block)
        @state_class = Operation::State.build(&block)
      end

      def step(step_name, options = {}, &block)
        sequence.add_step(step_name, options, &block)
      end

      def error(*steps, &block)
        steps.each do |step_name|
          sequence.add_error_handler_for_step(step_name, &block)
        end
      end

      def policy(klass, method_name)
        step :policy do |state, original_state|
          state.tap do
            policy_instance = klass.new(original_state.current_user, state)

            # pass the policy instance back in the NotAuthorized exception so
            # that the state, the user, and the policy can be inspected
            policy_instance.send(method_name) ||
              raise(NotAuthorized, policy_instance)
          end
        end
      end

      def middleware_class(&block)
        sequence.middleware_class_block = block
      end

      def middleware_step(step_name, options = {})
        sequence.add_middleware_step(step_name, options)
      end

      def validate(&block)
        # when we add a validation step, all proceeding steps must not produce
        # side-effects (subsequent steps are case-by-case)
        sequence.mark_as_side_effect_free!
        step :validate, side_effect_free: true do |state|
          Operation::State.eval_validation_directives_block(state, &block)
        end
      end

      def custom_validation(&block)
        # when we add a validation step, all proceeding steps must not produce
        # side-effects (subsequent steps are case-by-case)
        sequence.mark_as_side_effect_free!
        step :validate, side_effect_free: true do |state, original_state|
          Operation::State.eval_custom_validator_block(state, original_state, &block)
        end
      end

      def represent(representer)
        step :represent, side_effect_free: true do |state|
          representer.represent(state)
        end
      end

      def sequence
        @sequence ||= Operation::Sequence.new
      end

      private

      def error!(state)
        raise Error, state
      end

      def run_sequence(sequence_to_run, params = {})
        # state class can be nil if the schema is never defined. that's ok. in that
        # situation it's up to the first step to produce the original state and we'll pass
        # the params themselves in
        state = state_class && state_class.new(params)
        sequence_to_run.call(state || params)
      end
    end
  end
end
