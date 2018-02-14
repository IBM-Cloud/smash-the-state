module SmashTheState
  class Operation
    module Swagger
      class Attribute
        class BadType < StandardError; end

        SWAGGER_KEYS = [
          :name,
          :in,
          :description,
          :type,
          :format,
          # :required
        ].freeze

        attr_accessor(*SWAGGER_KEYS)
        attr_accessor :override_blocks, :block, :ref

        def initialize(name, type, options = {})
          @name        = symbolize(name)
          @type        = symbolize(type)
          @description = options[:description].to_s
          @required    = options[:required].present?
          @in          = symbolize(options[:in] || :body)
          @format      = symbolize(options[:format])
          @ref         = options[:ref]
          @block       = options[:schema]

          coerce_active_model_types_to_swagger_types

          @override_blocks = []
        end

        def mode(context)
          # a reference will pull in a Definition
          return :reference if ref

          if type == :object &&
             [::Swagger::Blocks::Nodes::SchemaNode,
              ::Swagger::Blocks::Nodes::ParameterNode].include?(context.class)
            return :schema_object
          end

          if type == :object &&
             context.is_a?(::Swagger::Blocks::Nodes::PropertyNode)
            return :property_object
          end

          # a primitive attribute is an attribute with a simple type (string, etc) that is
          # defined inline
          :primitive
        end

        def evaluate_to_parameter_block(context)
          attribute = self
          context.instance_eval do
            parameter do
              attribute.evaluate_type(self)
            end
          end
        end

        def evaluate_to_flat_properties(context)
          flat_properties = Swagger::FlatPropertiesSet.new
          flat_properties.instance_eval(&@block)
          flat_properties.evaluate_swagger(context)
        end

        # rubocop:disable Metrics/MethodLength
        def evaluate_type(context, options = {})
          attribute = self
          parent_context = options[:parent_context]
          mode = attribute.mode(context)

          context.instance_eval do
            case mode
            when :primitive then
              attribute.evaluate_as_primitive(self)
            when :reference then
              schema do
                attribute.evaluate_as_reference(self)
              end
            # swagger-blocks is super inconsistent.
            when :schema_object then
              # * schema nodes and parameter nodes have "schema" methods
              schema do
                attribute.evaluate_as_object(self)
              end
            when :property_object then
              # * property nodes can recurse with more property nodes
              attribute.evaluate_as_object(self)
            end

            if attribute.needs_additional_swagger_keys?(self, parent_context)
              attribute.evaluate_additional_swagger_keys(self)
            end

            attribute.evaluate_override_blocks(self)
          end
        end
        # rubocop:enable Metrics/MethodLength

        def needs_additional_swagger_keys?(context, parent_context)
          # swagger keys like "in" and "name" should not be present when the parent
          # context is a property or schema node
          return false if [
            ::Swagger::Blocks::Nodes::PropertyNode,
            ::Swagger::Blocks::Nodes::SchemaNode
          ].include?(parent_context.class)

          # the aforementioned swagger keys also should not be present for property nodes
          # in any situation
          return false if context.is_a?(::Swagger::Blocks::Nodes::PropertyNode)

          true
        end

        def evaluate_override_blocks(swagger_context)
          attribute = self
          swagger_context.instance_eval do
            if attribute.override_blocks
              attribute.override_blocks.each { |block| instance_eval(&block) }
            end
          end
        end

        def evaluate_as_primitive(swagger_context)
          attribute = self
          swagger_context.instance_eval do
            key :type, attribute.type
            key :format, attribute.format unless attribute.format.nil?
          end
        end

        def evaluate_as_reference(swagger_context)
          attribute = self

          swagger_context.instance_eval do
            key :'$ref', attribute.ref
          end
        end

        def evaluate_as_object(swagger_context)
          attribute = self
          swagger_context.instance_eval do
            key :type, :object
            key :properties, attribute.evaluate_to_flat_properties(self)
          end
        end

        def evaluate_additional_swagger_keys(swagger_context)
          attribute = self
          swagger_context.instance_eval do
            (SWAGGER_KEYS - [:type, :format]).each do |k|
              value = attribute.send(k)
              key(k, value) unless value == "" || value.nil?
            end
          end
        end

        private

        def evaluate_to_block(method_name, context)
          attribute = self

          context.instance_eval do
            send(method_name, attribute.name) do
              attribute.evaluate_type(self)
            end
          end
        end

        def symbolize(value)
          value && value.to_sym
        end

        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength
        def coerce_active_model_types_to_swagger_types
          case type
          when :state_for_smashing then
            @type = :object
            @format = nil
          when :big_integer then
            @type = :integer
            @format = :int64
          when :integer then
            @format = :int32
          when :date then
            @type = :string
            @format = :date
          when :date_time then
            @type = :string
            @format = :"date-time"
          when :decimal then
            @type   = :number
            @format = :float
          when :float then
            @type = :number
            @format = :float
          when :time then
            raise BadType, "time is not supported by Swagger 2.0. maybe use date-time?"
          when :value then
            @type = :string
            @format = nil
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
