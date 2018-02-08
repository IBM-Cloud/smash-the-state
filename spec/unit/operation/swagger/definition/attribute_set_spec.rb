require "spec_helper"

describe SmashTheState::Operation::Swagger::Definition::AttributeSet do
  let!(:subject) do
    SmashTheState::Operation::Swagger::Definition::AttributeSet
  end

  let!(:instance) do
    subject.new
  end

  before do
    instance.add_attribute(:some_property, :string)
  end

  let!(:property) do
    instance.swagger_attributes["some_property"]
  end

  describe "#add_attribute" do
    it "adds a Property rather than the normal Attribute" do
      expect(property).to be_a SmashTheState::Operation::Swagger::Property
      expect(property.type).to eq(:string)
    end
  end

  describe "#eval_swagger_param" do
    let!(:context) { double }

    it "evaluates the property as a property block" do
      expect(property).to receive(:evaluate_to_property_block).with(context)
      instance.eval_swagger_param(property, context)
    end
  end
end
