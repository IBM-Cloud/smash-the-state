module SmashTheState
  class Operation
    # fundamentally a definition is a re-usable schema block with a name
    class Definition < SmashTheState::Operation::State
      class << self
        attr_reader :schema_block

        # the "name" is available as a reference
        def ref
          @definition_name
        end

        # whenever this module is evaluated as a string, use its name
        alias to_s ref

        private

        # assigns a name to the definition
        def definition(definition_name)
          @definition_name = definition_name
        end

        def schema(name = nil, options = {}, &block)
          # if a name is provided, it's an inline schema or a reference to another
          # definition
          return super unless name.nil?

          # called with no name, we infer that this is the definition's own schema. the
          # provided schema block is both stored for re-use and also evaluated in the
          # definition module itself
          @schema_block = block
          class_eval(&block)
        end
      end
    end
  end
end
