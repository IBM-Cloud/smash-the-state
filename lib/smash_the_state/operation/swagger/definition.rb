module SmashTheState
  class Operation
    module Swagger
      class Definition < SmashTheState::Operation::State
        extend SmashTheState::Operation::Swagger

        # create an AttributeSet that uses properties instead of attributes
        class AttributeSet < SmashTheState::Operation::Swagger::AttributeSet
          def add_attribute(name, type, options = {})
            swagger_attributes[name] = Property.new(name, type, options)
          end

          def eval_swagger_param(attribute, swagger_context)
            attribute.evaluate_to_property_block(swagger_context)
          end
        end

        class << self
          def definition(definition_name)
            @definition_name = definition_name
          end

          def ref
            @definition_name
          end

          # swagger-blocks will to_s this class name into things like:
          # "#/definitions/#{definition_class.to_s}"
          alias to_s ref

          def schema(&block)
            class_eval(&block)
          end

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
