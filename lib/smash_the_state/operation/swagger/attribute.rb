module SmashTheState
  class Operation
    module Swagger
      class Attribute
        class BadType < StandardError; end

        SWAGGER_KEYS = [:name, :in, :description, :required, :type, :format].freeze

        attr_accessor(*SWAGGER_KEYS)
        attr_accessor :override_blocks

        def initialize(name, type, options)
          @name        = symbolize(name)
          @type        = symbolize(type)
          @description = options[:description].to_s
          @required    = options[:required].present?
          @in          = symbolize(options[:in] || :body)
          @format      = symbolize(options[:format])

          coerce_active_model_types_to_swagger_types

          @override_blocks = []
        end

        def evaluate_to_parameter_block(context)
          attribute = self
          override_blocks = attribute.override_blocks

          context.instance_eval do
            parameter do
              SWAGGER_KEYS.each do |k|
                key k, attribute.send(k)
              end

              if override_blocks
                override_blocks.each do |override_block|
                  instance_eval(&override_block)
                end
              end
            end
          end
        end

        private

        def symbolize(value)
          value && value.to_sym
        end

        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength
        def coerce_active_model_types_to_swagger_types
          case type
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
