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
      format:      nil
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
        expect(instance.required).to eq(options[:required].present?)
        expect(instance.in).to eq(options[:in].to_sym)
        expect(instance.format).to eq(nil)
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
      expect(context).to receive(:key).with(:required, instance.required)
      expect(context).to receive(:key).with(:format, instance.format)

      instance.evaluate_to_parameter_block(context)
    end
  end
end
