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
          side_effect_free: nil # nil roughly implies unknown
        }.merge(options)
      end

      def side_effect_free?
        options[:side_effect_free] == true
      end
    end
  end
end
