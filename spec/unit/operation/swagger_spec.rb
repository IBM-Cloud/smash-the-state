require "spec_helper"

describe SmashTheState::Operation::Swagger do
  let!(:subject) { SmashTheState::Operation::Swagger }
  let!(:klass) do
    Class.new.tap do |k|
      k.class_eval do
        include ActiveModel::Model
        include ActiveModelAttributes
        extend SmashTheState::Operation::Swagger

        attribute :first_name, :string, default: "Michael"
        attribute :last_name,  :string, default: "Huemer"
      end
    end
  end

  let!(:parameter) { double }
  let!(:context) { double(parameter: parameter) }

  let!(:first_name_attribute) do
    klass.attributes_registry[:first_name].last[:swagger_attribute]
  end

  let!(:last_name_attribute) do
    klass.attributes_registry[:last_name].last[:swagger_attribute]
  end

  describe "self#eval_swagger_params" do
    it "runs evaluate_to_parameter_block with the swagger context for each " \
       "attribute" do
      expect(
        first_name_attribute
      ).to receive(:evaluate_to_parameter_block).with(context)

      expect(
        last_name_attribute
      ).to receive(:evaluate_to_parameter_block).with(context)

      klass.eval_swagger_params(context)
    end
  end

  describe "self#override_swagger_param" do
    let!(:blk) { proc {} }

    context "with a known attribute" do
      before do
        klass.override_swagger_param(:first_name, &blk)
      end

      it "adds a swagger attribute override block" do
        expect(first_name_attribute.override_blocks).to include(blk)
      end
    end

    context "with an unknown attribute" do
      it "does nothing" do
        klass.override_swagger_param(:foo, &blk)
      end
    end
  end

  describe "self#override_swagger_params" do
    let!(:blk) { proc {} }

    before do
      klass.override_swagger_params(&blk)
    end

    it "adds a swagger attribute override block for each attribute" do
      expect(first_name_attribute.override_blocks).to include(blk)
      expect(last_name_attribute.override_blocks).to include(blk)
    end
  end
end
