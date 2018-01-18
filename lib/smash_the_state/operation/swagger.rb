require_relative 'swagger/attribute'

module SmashTheState
  class Operation
    module Swagger
      # see http://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html#method-i-attribute
      ACTIVE_MODEL_ATTRIBUTE_OPTIONS = [:default, :array, :range].freeze

      class AttributeSet
        attr_reader :swagger_attributes

        def initialize
          @swagger_attributes = HashWithIndifferentAccess.new
        end

        def add(name, type, options = {})
          swagger_attributes[name] = Attribute.new(name, type, options)
        end

        def eval_swagger_params(swagger_context)
          swagger_attributes.keys.each do |name|
            attribute = swagger_attributes[name]

            if attribute.is_a? Attribute
              attribute.evaluate_to_parameter_block(swagger_context)
            elsif attribute.is_a? Thing
              property
            end
          end
        end

        def override_swagger_param(name, &block)
          attr = swagger_attributes[name]
          return if attr.nil?

          attr.override_blocks << block
        end

        def override_swagger_params(&block)
          swagger_attributes.keys.each do |name|
            swagger_attributes[name].override_blocks << block
          end
        end
      end

      # delegating most of the behavior out of the core Smash schema to avoid polluting it
      # unnecessarily and also to allow for other abstractions with other libraries
      delegate :eval_swagger_params,
               :override_swagger_param,
               :override_swagger_params, to: :attribute_set

      attr_reader :attribute_set

      private

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
        @attribute_set ||= AttributeSet.new
        @attribute_set.add(name, type, options)
      end
    end
  end
end
