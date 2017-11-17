module SmashTheState
  class Operation
    class Error < StandardError
      attr_reader :state

      def initialize(state)
        @state = state
      end
    end

    class NotAuthorized < StandardError
      attr_reader :policy_instance

      def initialize(policy_instance)
        @policy_instance = policy_instance
      end
    end
  end
end
