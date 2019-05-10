require "spec_helper"

# not sure why getting a `NoMethodError: undefined method `empty?' for nil:NilClass` error
# when the literal module is referenced here as opposed to as a string
describe "SmashTheState::Operation::Definition" do
  let!(:subject) do
    location_definition = Class.new(SmashTheState::Operation::Definition).tap do |k|
      k.class_eval do
        definition "Location"

        schema do
          attribute :postal_code, :string
          attribute :lat, :float
          attribute :lon, :float
        end
      end
    end

    Class.new(SmashTheState::Operation::Definition).tap do |k|
      k.class_eval do
        definition "Syndicate"

        schema do
          # smoke test nested definitions
          schema :location, ref: location_definition
        end
      end
    end
  end

  describe "inheritance" do
    it "inherits from State" do
      expect(subject.ancestors).to include(SmashTheState::Operation::State)
    end
  end

  describe "#ref" do
    it "returns the definition name" do
      expect(subject.ref).to eq("Syndicate")
    end
  end

  describe "#to_s" do
    it "returns the ref" do
      expect(subject.to_s).to eq(subject.ref)
    end
  end

  describe "#schema with a referenced definition" do
    it "pulls in the schema from the referened definition" do
      expect(
        # wheeeeeee
        subject.attributes_registry[:location][1][:ref].attributes_registry.keys
      ).to eq(%i[postal_code lat lon])
    end
  end
end
