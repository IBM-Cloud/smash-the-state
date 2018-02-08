require_relative 'definition/attribute_set'

module SmashTheState
  class Operation
    module Swagger
      module Definition
        def self.extended(base)
          base.instance_eval do
            extend SmashTheState::Operation::Swagger
            extend ClassMethods
            attr_reader :schema_block

            @attribute_set = SmashTheState::Operation::Swagger::Definition::AttributeSet.new
          end
        end

        module ClassMethods
          def eval_to_swagger_block(swagger_context)
            definition = self

            # see https://github.com/fotinakis/swagger-blocks/blob/4a5d33939e49f4417f1fc52896a3c30b69a5b27c/lib/swagger/blocks/class_methods.rb#L35
            swagger_context.send(:swagger_schema, ref) do
              definition.eval_swagger(self, nil)
            end
          end

          private

          def attribute_strategy
            :property
          end
        end
      end
    end
  end
end
