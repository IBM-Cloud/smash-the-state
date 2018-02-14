module SmashTheState
  class Operation
    module Swagger
      class FlatPropertiesSet < AttributeSet
        def attribute(key, type, options = {})
          add_attribute(key, type, options)
        end

        def schema(key, options = {}, &block)
          # :state_for_smashing becomes type :object behind the scenes
          add_attribute(key, :state_for_smashing, options.merge(schema: block))
        end

        def evaluate_swagger(swagger_context)
          flat_properties_set = self

          Hash[flat_properties_set.swagger_attributes.map do |name, attr|
            swagger_context.instance_eval do
              # this is a bit of a hack and I'm not sure what node type is most
              # appropriate
              node = ::Swagger::Blocks::Nodes::ParameterNode.call(version: version)
              attr.evaluate_type(node, parent_context: swagger_context)
              [name, node]
            end
          end]
        end
      end
    end
  end
end
