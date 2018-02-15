require "spec_helper"

describe "Swagger" do
  definition = Class.new(SmashTheState::Operation::Definition).tap do |k|
    k.class_eval do
      extend SmashTheState::Operation::Swagger::Definition
      definition "MyDefinition"

      schema do
        attribute :foo, :string
        attribute :bar, :integer
      end
    end
  end

  let!(:subject) do
    Class.new(SmashTheState::Operation).tap do |k|
      k.class_eval do
        schema do
          extend SmashTheState::Operation::Swagger

          attribute :id, :string, in: :query
          attribute :count, :integer
          attribute :cost, :big_integer
          attribute :created_at, :date
          attribute :expires_at, :date_time
          attribute :completeness, :decimal
          attribute :latitude, :float

          schema :inline do
            attribute :baz, :boolean
          end

          schema :definition, ref: definition
        end
      end
    end
  end

  let!(:swagger_context) do
    node = Swagger::Blocks::Nodes::OperationNode.new
    node.version = "2.0"
    node
  end

  let!(:controller_context) do
    Class.new.tap do |k|
      k.class_eval do
        include Swagger::Blocks
        swagger_root host: 'petstore.swagger.wordnik.com' do
        end
      end
    end
  end

  it "produces a swagger spec" do
    subject.eval_swagger(swagger_context, controller_context)
    swagger_data = swagger_context.data[:parameters].map(&:data)

    expect(swagger_data[0..-3]).to eq(
      [
        { type: :string,                        name: :id,           in: :query },
        { type: :integer, format: :int32,       name: :count,        in: :body  },
        { type: :integer, format: :int64,       name: :cost,         in: :body  },
        { type: :string,  format: :date,        name: :created_at,   in: :body  },
        { type: :string,  format: :"date-time", name: :expires_at,   in: :body  },
        { type: :number,  format: :float,       name: :completeness, in: :body  },
        { type: :number,  format: :float,       name: :latitude,     in: :body  }
      ]
    )

    inline_swagger = swagger_data.slice(-2, 1).first
    expect(inline_swagger[:schema]).to be_a Swagger::Blocks::Nodes::SchemaNode
    expect(inline_swagger[:schema].data[:type]).to eq(:object)
    expect(inline_swagger[:schema].data[:properties]["baz"]).to be_a(
      Swagger::Blocks::Nodes::ParameterNode
    )
    expect(inline_swagger[:schema].data[:properties]["baz"].data[:type]).to eq(:boolean)
    expect(inline_swagger[:name]).to eq(:inline)
    expect(inline_swagger[:in]).to eq(:body)

    definition_swagger = swagger_data.last[:schema]
    expect(definition_swagger).to be_a Swagger::Blocks::Nodes::SchemaNode
    expect(definition_swagger.data[:'$ref']).to eq(definition)
  end
end
