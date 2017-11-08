require_relative 'swagger/attribute'

module SmashTheState
  class Operation
    module Swagger
      def eval_swagger_params(swagger_context)
        attributes_registry.each do |_name, (_type, options)|
          options[:swagger_attribute].
            evaluate_to_parameter_block(swagger_context)
        end
      end

      def override_swagger_param(name, &block)
        attr = attributes_registry[name]
        return if attr.nil?

        options = attr.last
        options[:swagger_attribute].override_blocks << block
      end

      def override_swagger_params(&block)
        attributes_registry.each do |_key, attr|
          options = attr.last
          options[:swagger_attribute].override_blocks << block
        end
      end

      private

      def attribute(name, type, options = {})
        super name, type, options.merge(
          swagger_attribute: Attribute.new(name, type, options)
        )
      end
    end
  end
end
