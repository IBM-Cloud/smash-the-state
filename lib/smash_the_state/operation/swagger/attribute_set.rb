module SmashTheState
  class Operation
    module Swagger
      class AttributeSet
        attr_reader :swagger_attributes

        def initialize
          @swagger_attributes = HashWithIndifferentAccess.new
        end

        # an attribute is a type on a schema
        def add_attribute(name, type, options = {})
          swagger_attributes[name] = Attribute.new(name, type, options)
        end

        # swagger differentiates between attributes and properties, but really they're
        # almost exactly the same. still, we need to differentiate
        def add_property(name, type, options = {})
          swagger_attributes[name] = Property.new(name, type, options)
        end

        # this method will be called from a swagger-blocks context like a Rails controller
        def eval_swagger(swagger_operation, swagger_context)
          swagger_attributes.keys.each do |name|
            eval_swagger_param(swagger_attributes[name], swagger_operation)
          end

          eval_swagger_definitions(swagger_context)
        end

        # provides an interface for overriding a swagger parameter in a swagger-blocks context
        def override_swagger_param(name, &block)
          attr = swagger_attributes[name]
          return if attr.nil?

          attr.override_blocks << block
        end

        # provides an interface for overriding several swagger parameters in a
        # swagger-blocks context
        def override_swagger_params(&block)
          swagger_attributes.keys.each do |name|
            swagger_attributes[name].override_blocks << block
          end
        end

        def add_definition(definition)
          definitions.push(definition).uniq!
        end

        def definitions
          @definitions ||= []
        end

        private

        def eval_swagger_definitions(swagger_context)
          definitions.each { |d| d.eval_to_swagger_block(swagger_context) }
        end

        def eval_swagger_param(attribute, swagger_context)
          attribute.evaluate_to_parameter_block(swagger_context)
        end
      end
    end
  end
end
