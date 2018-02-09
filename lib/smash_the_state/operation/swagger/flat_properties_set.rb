module SmashTheState
  class Operation
    module Swagger
      class FlatPropertiesSet < AttributeSet
        def attribute(key, type, options = {})
          add_attribute(key, type, options)
        end

        def schema(key, options = {}, &block)
          add_attribute(key, :state_for_smashing, options.merge(schema: block))
        end

        def evaluate_swagger(context)
          flat_properties_set = self

          context.instance_eval do
            Hash[flat_properties_set.swagger_attributes.map do |name, attr|
              # this is sort of a hack and I'm not sure what node type is most appropriate
              node = ::Swagger::Blocks::Nodes::ParameterNode.call(version: version)
              attr.evaluate_type(node, parent_context: context)
              [name, node]
            end]
          end
        end
      end
    end
  end
end
