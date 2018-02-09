require_relative 'swagger/attribute'
require_relative 'swagger/property'
require_relative 'swagger/attribute_set'
require_relative 'swagger/flat_properties_set'
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

      # an attribute set is a collection of swagger attributes and is a place to keep the
      # swagger-specific behaviors so that it is kept out of the way of the main operation
      # logic
      attr_reader :attribute_set

      def self.extended(base)
        base.instance_eval do
          @attribute_set = SmashTheState::Operation::Swagger::AttributeSet.new
        end
      end

      private

      # the standard strategy for defining swagger-blocks is with attributes. in the case
      # of a Definition, which inherits from this module, it becomes properties. so this
      # method is overridden in Definition
      def attribute_strategy
        :attribute
      end

      # similar to #attribute_strategy, the attribute set typically is a collection of
      # attributes. but other classes inherit from this class, so it can be overridden
      def attribute_set_class
        SmashTheState::Operation::Swagger::AttributeSet
      end

      # hijack the attribute method that is provided by activemodel attributes
      def attribute(name, type, options = {})
        # run the standard active model-y attribute-adding code before custom behaviors
        super(
          name,
          type,
          options.select do |k|
            ACTIVE_MODEL_ATTRIBUTE_OPTIONS.include? k
          end
        )

        @attribute_set.send("add_#{attribute_strategy}", name, type, options)
        return if options[:ref].nil?

        # add any referenced type definitions to the operation so that they can also be
        # evaluated in a swagger block
        @attribute_set.add_definition(options[:ref])
      end
    end
  end
end
