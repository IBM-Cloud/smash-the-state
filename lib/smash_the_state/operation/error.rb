module SmashTheState
  class Operation
    class Error < StandardError
      attr_reader :state

      def initialize(state)
        @state = state
      end
    end

    class NotAuthorized < Error; end
  end
end
