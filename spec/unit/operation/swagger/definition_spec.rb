require "spec_helper"

describe SmashTheState::Operation::Swagger::Definition do
  let!(:subject) { SmashTheState::Operation::Swagger::Definition }

  describe "when extending a general class" do
    let!(:base_class) { Class.new }
    let!(:extended) { base_class.extend(subject) }

    it "extends class methods, adds schema_block reader" do
      expect(base_class).to respond_to :attribute_set
      expect(base_class).to respond_to :eval_to_swagger_block
      expect(base_class.new).to respond_to :schema_block
    end
  end

  describe "when extending a Definition class" do
    let!(:base_class) do
      Class.new(SmashTheState::Operation::Definition).tap do |k|
        k.class_eval do
          definition "Flag"
        end
      end
    end

    let!(:extended) { base_class.extend(subject) }

    describe "self#eval_to_swagger_block" do
      let!(:context) { double }
      let!(:fake_ref) { double }

      it "evaluates the definition as swagger into a swagger_schema block" do
        expect(context).to receive(:swagger_schema).with(base_class.ref).and_yield
        expect(base_class).to receive(:eval_swagger).with(base_class, nil)
        expect(extended.eval_to_swagger_block(context))
      end
    end
  end
end
