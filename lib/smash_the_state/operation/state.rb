require "active_support/core_ext/hash/indifferent_access"

module SmashTheState
  class Operation
    class State
      include ActiveModel::Model
      include ActiveModelAttributes

      DEFAULT_MODEL_NAME = "State".freeze

      class Invalid < StandardError
        attr_reader :state

        def initialize(state)
          @state = state
        end
      end

      class << self
        attr_accessor :representer

        def build(params = nil, &block)
          Class.new(self) do
            class_exec(params, &block)
          end
        end

        # defines a nested schema inside of a state. can be nested arbitrarily
        # deep. schemas may be described inline via a block *or* can be a reference to a
        # definition
        def schema(key, options = {}, &block)
          attribute key,
                    :state_for_smashing,
                    **options.merge(
                      # allow for schemas to be provided inline *or* as a reference to a
                      # type definition
                      schema: attribute_options_to_ref_block(options) || block
                    )
        end

        # for ActiveModel states we will treat the block as a collection of ActiveModel
        # validator directives
        def eval_validation_directives_block(state, &block)
          # each validate block should be a "fresh start" and not interfere with the
          # previous blocks
          state.singleton_class.clear_validators!
          state.singleton_class.class_eval(&block)

          state.validate || invalid!(state)
          state
        end

        def extend_validation_directives_block(state, &block)
          state.class_eval(&block)

          state
        end

        # for non-ActiveModel states we will just evaluate the block as a validator
        def eval_custom_validator_block(state, original_state = nil)
          yield(state, original_state)
          invalid!(state) if state.errors.present?
          state
        end

        def model_name(model_name = nil)
          @_model_name = model_name if model_name.present?
          ActiveModel::Name.new(self, nil, @_model_name || DEFAULT_MODEL_NAME)
        end

        private

        # if a reference to a definition is provided, use the reference schema block
        def attribute_options_to_ref_block(options)
          options[:ref]&.schema_block
        end

        def invalid!(state)
          raise Invalid, state
        end
      end

      attr_accessor :current_user

      def initialize(attributes = {})
        @current_user = attributes.delete(:current_user) ||
                        attributes.delete("current_user")

        indifferent_whitelisted_attributes = self.
                                               class.
                                               attributes_registry.
                                               with_indifferent_access

        # ActiveModel will raise an ActiveRecord::UnknownAttributeError if any unexpected
        # attributes are passed in. since operations are meant to replace strong
        # parameters and enforce against arbitrary mass assignment, we should filter the
        # params to inclide only the whitelisted attributes.
        # TODO: what about nested attributes?
        whitelisted_attributes = attributes.select do |attribute|
          indifferent_whitelisted_attributes.key? attribute
        end

        super(whitelisted_attributes)
      end

      def as_json
        Hash[self.class.attributes_registry.keys.map do |key|
          [key, send(key).as_json]
        end]
      end
    end
  end
end
