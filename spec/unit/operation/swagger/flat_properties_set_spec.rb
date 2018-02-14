require "spec_helper"

describe SmashTheState::Operation::Swagger::FlatPropertiesSet do
  let!(:subject) { SmashTheState::Operation::Swagger::FlatPropertiesSet }
  let!(:instance) { SmashTheState::Operation::Swagger::FlatPropertiesSet.new }

  describe "#attribute" do
    let!(:schema_block) { proc {} }

    before do
      instance.attribute(:color, :string, schema: schema_block)
    end

    it "adds an attribute" do
      expect(instance.swagger_attributes.key?(:color)).to eq(true)
      expect(instance.swagger_attributes[:color].block).to eq(schema_block)
    end
  end

  describe "#schema" do
    before do
      instance.schema(:color) do
        instance.trigger
      end
    end

    it "adds the key as an object with the options and schema block" do
      attributes = instance.swagger_attributes

      expect(attributes[:color].type).to eq(:object)
      expect(instance).to receive(:trigger)
      attributes[:color].block.call
    end
  end

  describe "#evaluate_swagger" do
    let!(:swagger_context) { double(version: "2.0") }

    before do
      instance.attribute(:color, :string)
      instance.attribute(:count, :integer)
    end

    it "returns a of key/node pairs" do
      attrs = instance.evaluate_swagger(swagger_context)
      expect(attrs["color"].data).to eq(type: :string, name: :color, in: :body)
      expect(attrs["count"].data).to eq(type: :integer, name: :count, in: :body, format: :int32)
    end
  end
end
