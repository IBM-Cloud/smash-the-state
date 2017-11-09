require_relative 'swagger/attribute'

module SmashTheState
  class Operation
    module Swagger
      # see http://api.rubyonrails.org/classes/ActiveRecord/Attributes/ClassMethods.html#method-i-attribute
      ACTIVE_MODEL_ATTRIBUTE_OPTIONS = [:default, :array, :range].freeze

      def eval_swagger_params(swagger_context)
        attributes_registry.each do |name, _meta|
          swagger_attributes[name].
            evaluate_to_parameter_block(swagger_context)
        end
      end

      def override_swagger_param(name, &block)
        attr = swagger_attributes[name]
        return if attr.nil?

        attr.override_blocks << block
      end

      def override_swagger_params(&block)
        attributes_registry.each do |name, _meta|
          swagger_attributes[name].override_blocks << block
        end
      end

      def swagger_attributes
        @swagger_attributes || {}
      end

      private

      def attribute(name, type, options = {})
        @swagger_attributes ||= {}
        @swagger_attributes[name] = Attribute.new(name, type, options)

        super(
          name,
          type,
          options.select do |k|
            ACTIVE_MODEL_ATTRIBUTE_OPTIONS.include? k
          end
        )
      end
    end
  end
end
