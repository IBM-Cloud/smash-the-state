module SmashTheState
  class Operation
    class StateType < ActiveModel::Type::Value
      def initialize(block)
        @schema_class = Operation::State.build(&block)
      end

      private

      def cast_value(attributes)
        @schema_class.new(attributes)
      end
    end
  end
end

ActiveModel::Type.register(:state_for_smashing) do |_name, options|
  SmashTheState::Operation::StateType.new(options[:schema])
end
