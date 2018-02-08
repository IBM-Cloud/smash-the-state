module SmashTheState
  class Operation
    module Swagger
      module Definition
        # create an AttributeSet that uses properties instead of attributes
        class AttributeSet < SmashTheState::Operation::Swagger::AttributeSet
          def add_attribute(name, type, options = {})
            swagger_attributes[name] = Property.new(name, type, options)
          end

          def eval_swagger_param(property, swagger_context)
            property.evaluate_to_property_block(swagger_context)
          end
        end
      end
    end
  end
end
