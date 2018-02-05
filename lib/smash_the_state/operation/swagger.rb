require_relative 'swagger/attribute'
require_relative 'swagger/property'
require_relative 'swagger/attribute_set'
require_relative 'swagger/definition'

module SmashTheState
  class Operation
    module Swagger
      # see http://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html#method-i-attribute
      ACTIVE_MODEL_ATTRIBUTE_OPTIONS = [:default, :array, :range, :schema].freeze

      # delegating most of the behavior out of the core Smash schema to avoid polluting it
      # unnecessarily and also to allow for other abstractions with other libraries
      delegate :eval_swagger,
               :override_swagger_param,
               :override_swagger_params, to: :attribute_set

      attr_reader :attribute_set

      private

      def attribute_strategy
        :attribute
      end

      def attribute_set_class
        SmashTheState::Operation::Swagger::AttributeSet
      end

      # hijack the attribute method
      def attribute(name, type, options = {})
        # run the standard attribute-adding code
        super(
          name,
          type,
          options.select do |k|
            ACTIVE_MODEL_ATTRIBUTE_OPTIONS.include? k
          end
        )

        # swaggerize the attribute with a Swagger::AttributeSet
        @attribute_set ||= attribute_set_class.new
        @attribute_set.send("add_#{attribute_strategy}", name, type, options)

        return if options[:ref].nil?

        # add any referenced type definitions to the operation so that they can also be
        # evaluated in a swagger block
        @attribute_set.add_definition(options[:ref])
      end
    end
  end
end
