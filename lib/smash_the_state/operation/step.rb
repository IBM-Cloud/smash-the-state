module SmashTheState
  class Operation
    class Step
      attr_accessor :error_handler
      attr_reader :name, :implementation, :options

      def initialize(step_name, options = {}, &block)
        @name           = step_name
        @implementation = block
        @options        = {
          # defaults
          dry_run_safe: false
        }.merge(options)
      end

      def dry_run_safe?
        options[:dry_run_safe] == true
      end
    end
  end
end
