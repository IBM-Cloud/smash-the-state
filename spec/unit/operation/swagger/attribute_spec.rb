require "spec_helper"

describe SmashTheState::Operation::Swagger::Attribute do
  let!(:subject) { SmashTheState::Operation::Swagger::Attribute }
  let!(:name) { "something" }
  let!(:type) { "string" }

  let!(:options) do
    {
      description: :"a-description",
      required:    "true",
      in:          "body",
      format:      :byte
    }
  end

  describe "#initialize" do
    context "in general" do
      let!(:instance) { subject.new(name, type, options) }

      it "sets its keys, symbolizing name, type, in, and format, " \
         "stringifying description, and booleanizing required" do
        expect(instance.name).to eq(name.to_sym)
        expect(instance.type).to eq(type.to_sym)
        expect(instance.description).to eq(options[:description].to_s)
        expect(instance.in).to eq(options[:in].to_sym)
        expect(instance.format).to eq(:byte)
      end
    end

    context "with a big_integer type" do
      let!(:instance) do
        subject.new(name, :big_integer, options)
      end

      it "coerces to :integer type and :int64 format" do
        expect(instance.type).to eq(:integer)
        expect(instance.format).to eq(:int64)
      end
    end

    context "with a integer type" do
      let!(:instance) do
        subject.new(name, :integer, options)
      end

      it "coerces to :int32 format" do
        expect(instance.type).to eq(:integer)
        expect(instance.format).to eq(:int32)
      end
    end

    context "with a date type" do
      let!(:instance) do
        subject.new(name, :date, options)
      end

      it "coerces to :string type and :date format" do
        expect(instance.type).to eq(:string)
        expect(instance.format).to eq(:date)
      end
    end

    context "with a date_time type" do
      let!(:instance) do
        subject.new(name, :date_time, options)
      end

      it "coerces to :string type and :date-time format" do
        expect(instance.type).to eq(:string)
        expect(instance.format).to eq(:"date-time")
      end
    end

    context "with a decimal type" do
      let!(:instance) do
        subject.new(name, :decimal, options)
      end

      it "coerces to :number type and :float format" do
        expect(instance.type).to eq(:number)
        expect(instance.format).to eq(:float)
      end
    end

    context "with a time type" do
      it "raises an exception" do
        expect do
          subject.new(name, :time, options)
        end.to raise_exception SmashTheState::Operation::Swagger::Attribute::BadType
      end
    end

    context "with a value type" do
      let!(:instance) do
        subject.new(name, :value, options)
      end

      it "coerces to :string type" do
        expect(instance.type).to eq(:string)
        expect(instance.format).to eq(nil)
      end
    end
  end

  describe "#evaluate_to_parameter_block" do
    let!(:context) { double }
    let!(:instance) { subject.new(name, type, options) }

    before do
      allow(context).to receive(:parameter).and_yield
    end

    it "creates a parameter block with each key, then evals the override " \
       "blocks in the parameter block in the order in which they were added" do
      instance.override_blocks << proc do
        key :in, :query
      end

      instance.override_blocks << proc do
        key :in, :path
      end

      expect(context).to receive(:key).with(:name, instance.name)
      expect(context).to receive(:key).once.with(:in, :body)
      expect(context).to receive(:key).once.with(:in, :query)
      expect(context).to receive(:key).once.with(:in, :path)
      expect(context).to receive(:key).with(:description, instance.description)
      expect(context).to receive(:key).with(:type, instance.type)
      expect(context).to receive(:key).with(:format, instance.format)

      instance.evaluate_to_parameter_block(context)
    end
  end

  describe "#evaluate_to_flat_properties" do
    let!(:context) { double(version: "2.0") }
    let!(:schema_block) do
      proc do
        attribute :name, :string
      end
    end

    let!(:instance) do
      subject.new(name, type, options.merge(schema: schema_block))
    end

    it "evaluates the block to a hash of key/node pairs" do
      attr = instance.evaluate_to_flat_properties(context)
      expect(attr["name"].data).to eq(type: :string, name: :name, in: :body)
    end
  end

  describe "#needs_additional_swagger_keys?" do
    let!(:property_node) { ::Swagger::Blocks::Nodes::PropertyNode.new }
    let!(:schema_node) { ::Swagger::Blocks::Nodes::SchemaNode.new }
    let!(:parameter_node) { ::Swagger::Blocks::Nodes::ParameterNode.new }

    let!(:instance) do
      subject.new(:foo, :string)
    end

    describe "with a property node parent context" do
      it "returns false" do
        expect(
          instance.needs_additional_swagger_keys?(parameter_node, property_node)
        ).to eq(false)
      end
    end

    describe "with a schema node parent context" do
      it "returns false" do
        expect(
          instance.needs_additional_swagger_keys?(parameter_node, schema_node)
        ).to eq(false)
      end
    end

    describe "with a property node context" do
      it "returns false" do
        expect(
          instance.needs_additional_swagger_keys?(property_node, nil)
        ).to eq(false)
      end
    end

    describe "with something else" do
      it "returns true" do
        expect(
          instance.needs_additional_swagger_keys?(parameter_node, nil)
        ).to eq(true)
      end
    end
  end

  describe "#evaluate_as_primitive" do
    let!(:context) { double }

    describe "with type that has a format" do
      let!(:instance) do
        subject.new(:foo, :integer)
      end

      it "sets the type and format key in the provided context" do
        expect(context).to receive(:key).with(:type, :integer)
        expect(context).to receive(:key).with(:format, :int32)
        instance.evaluate_as_primitive(context)
      end
    end

    describe "with a type that has no format" do
      let!(:instance) do
        subject.new(:foo, :string)
      end

      it "sets just type in the provided context" do
        expect(context).to receive(:key).with(:type, :string)
        expect(context).to_not receive(:key).with(:format, :int32)
        instance.evaluate_as_primitive(context)
      end
    end
  end

  describe "#evaluate_as_reference" do
    let!(:context) { double }
    let!(:ref) { double }
    let!(:instance) do
      subject.new(:foo, :string, ref: ref)
    end

    it "sets the $ref key to ref in the provided context" do
      expect(context).to receive(:key).with(:'$ref', ref)
      instance.evaluate_as_reference(context)
    end
  end

  describe "#evaluate_as_object" do
    let!(:context) { double(version: "2.0") }
    let!(:ref) { double }
    let!(:schema_block) do
      proc do
        attribute :name, :string
        attribute :count, :integer
      end
    end

    let!(:instance) do
      subject.new(:foo, :string, schema: schema_block)
    end

    let!(:fake_flat_properties) { double }

    it "sets the type to :object and :properties to a flat property map " \
       "in the provided context" do
      allow(instance).to receive(:evaluate_to_flat_properties).
                           with(context).
                           and_return(fake_flat_properties)

      expect(context).to receive(:key).with(:type, :object)
      expect(context).to receive(:key).with(:properties, fake_flat_properties)

      instance.evaluate_as_object(context)
    end
  end

  describe "#evaluate_type" do
    let!(:context) { double(version: "2.0") }
    let!(:parent) { double }
    let!(:instance) do
      subject.new(:foo, :string)
    end

    before do
      allow(instance).to receive(:evaluate_as_primitive).with(context)
      allow(instance).to receive(:evaluate_additional_swagger_keys).with(context)
      allow(instance).to receive(:evaluate_override_blocks).with(context)
    end

    describe "as a primitive" do
      before do
        allow(instance).to receive(:mode).with(context).and_return(:primitive)
      end

      it "evaluates the attribute as a primitive in the provided context" do
        expect(instance).to receive(:evaluate_as_primitive).with(context)
        instance.evaluate_type(context)
      end
    end

    describe "as a reference" do
      before do
        allow(instance).to receive(:mode).with(context).and_return(:reference)
      end

      it "evaluates the attribute as reference in the provided context" do
        expect(context).to receive(:schema).and_yield
        expect(instance).to receive(:evaluate_as_reference).with(context)
        instance.evaluate_type(context)
      end
    end

    describe "as a schema_object" do
      before do
        allow(instance).to receive(:mode).with(context).and_return(:schema_object)
      end

      it "evaluates the attribute as an object in the provided " \
         "context, in a schema" do
        expect(context).to receive(:schema).and_yield
        expect(instance).to receive(:evaluate_as_object).with(context)
        instance.evaluate_type(context)
      end
    end

    describe "as a property_object" do
      before do
        allow(instance).to receive(:mode).with(context).and_return(:property_object)
      end

      it "evaluates the attribute as an object in the provided context" do
        expect(instance).to receive(:evaluate_as_object).with(context)
        instance.evaluate_type(context)
      end
    end

    describe "when additional swagger keys are needed" do
      before do
        allow(instance).to receive(:needs_additional_swagger_keys?).
                             with(context, parent).and_return(true)
      end

      it "evaluates additional swagger keys" do
        expect(instance).to receive(:evaluate_additional_swagger_keys).
                              with(context)
        instance.evaluate_type(context, parent_context: parent)
      end
    end

    describe "when additional swagger keys are not needed" do
      before do
        allow(instance).to receive(:needs_additional_swagger_keys?).
                             with(context, parent).and_return(false)
      end

      it "does not evaluate additional swagger keys" do
        expect(instance).to_not receive(:evaluate_additional_swagger_keys).
                                  with(context)
        instance.evaluate_type(context, parent_context: parent)
      end
    end

    it "evaluates override blocks" do
      expect(instance).to receive(:evaluate_override_blocks).
                            with(context)
      instance.evaluate_type(context)
    end
  end
end
