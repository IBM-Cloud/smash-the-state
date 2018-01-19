module SmashTheState
  class Operation
    module Swagger
      class Property < Attribute
        def evaluate_to_property_block(context)
          evaluate_to_block(:property, context)
        end
      end
    end
  end
end
