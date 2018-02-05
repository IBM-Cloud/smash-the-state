module SmashTheState
  class Operation
    class Definition < SmashTheState::Operation::State
      class << self
        attr_reader :schema_block

        def definition(definition_name)
          @definition_name = definition_name
        end

        def ref
          @definition_name
        end

        alias to_s ref

        def schema(&block)
          @schema_block = block
          class_eval(&block)
        end
      end
    end
  end
end
