module SmashTheState
  class Operation
    class State
      include ActiveModel::Model
      include ActiveModelAttributes

      class Invalid < StandardError
        attr_reader :state

        def initialize(state)
          @state = state
        end
      end

      class << self
        attr_accessor :representer

        def build(&block)
          Class.new(self).tap do |k|
            k.class_eval(&block)
          end
        end

        # for ActiveModel states we will treat the block as a collection of ActiveModel
        # validator directives
        def eval_validation_directives_block(state, &block)
          state.tap do |s|
            # each validate block should be a "fresh start" and not interfere with the
            # previous blocks
            s.class.clear_validators!
            s.class_eval(&block)
            s.validate || invalid!(s)
          end
        end

        # for non-ActiveModel states we will just evaluate the block as a validator
        def eval_custom_validator_block(state, &block)
          state.tap do |s|
            s.instance_eval(&block)
            invalid!(s) if s.errors.present?
          end
        end

        def model_name
          ActiveModel::Name.new(self, nil, "State")
        end

        private

        def invalid!(state)
          raise Invalid, state
        end
      end

      attr_accessor :current_user

      def initialize(attributes = {})
        @current_user = attributes.delete(:current_user) ||
                        attributes.delete("current_user")
        super(attributes)
      end

      def as_json
        Hash[self.class.attributes_registry.keys.map do |key|
          [key, send(key)]
        end]
      end
    end
  end
end
