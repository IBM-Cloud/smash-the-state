module SmashTheState
  class Operation
    class StateType < ActiveModel::Type::Value
      def initialize(block, options)
        @schema_class = Operation::State.build(&block)
        @is_array = options[:array]
      end

      private

      def array?
        @is_array == true
      end

      def wrap_array(value)
        return value if value.is_a? Array
        [value]
      end

      def cast_value(attributes)
        return wrap_array(attributes).map { |a| _cast_value(a) } if array?
        _cast_value(attributes)
      end

      def _cast_value(attributes)
        @schema_class.new(attributes)
      end
    end
  end
end

ActiveModel::Type.register(:state_for_smashing) do |_name, options|
  SmashTheState::Operation::StateType.new(options[:schema], options)
end
