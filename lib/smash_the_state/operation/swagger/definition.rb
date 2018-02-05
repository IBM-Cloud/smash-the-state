module SmashTheState
  class Operation
    module Swagger
      module Definition
        # create an AttributeSet that uses properties instead of attributes
        class AttributeSet < SmashTheState::Operation::Swagger::AttributeSet
          def add_attribute(name, type, options = {})
            swagger_attributes[name] = Property.new(name, type, options)
          end

          def eval_swagger_param(attribute, swagger_context)
            attribute.evaluate_to_property_block(swagger_context)
          end
        end

        def self.extended(base)
          base.instance_eval do
            extend SmashTheState::Operation::Swagger
            extend ClassMethods
            attr_reader :schema_block
          end
        end

        module ClassMethods
          def eval_to_swagger_block(swagger_context)
            definition = self
            swagger_context.send(:swagger_schema, ref) do
              definition.eval_swagger(self, nil)
            end
          end

          private

          def attribute_strategy
            :property
          end

          def attribute_set_class
            SmashTheState::Operation::Swagger::Definition::AttributeSet
          end
        end
      end
    end
  end
end
