module SmashTheState
  class Operation
    class Step
      attr_accessor :error_handler
      attr_reader :name, :implementation

      def initialize(step_name, &block)
        @name           = step_name
        @implementation = block
      end
    end
  end
end
