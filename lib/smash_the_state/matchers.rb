module SmashTheState
  module Matchers
    RSpec::Matchers.define :continue_from do |original|
      match do |continuation|
        expect(
          continuation.
            sequence.
            steps.
            slice(0, original.sequence.steps.length)
        ).to eq(original.sequence.steps)
      end
    end

    # expect(Some::Operation).to represent_with Thing::Representer
    RSpec::Matchers.define :represent_with do |representer|
      match do |operation|
        expect(representer).to receive(:represent).and_return "representation"
        expect(operation.call.as_json).to eq "representation"
      end

      # Magic: Calling this matcher with an operation works the way you'd expect. Calling it with
      # a block turns the block into a proc and stuffs it into |operation|. Since operations and
      # procs both respond to .call in the same way, `operation.call.as_json` does the same thing
      # in both cases.
      def supports_block_expectations?
        true
      end
    end

    # expect(Some::Operation).to represent_collection_with Thing::Representer
    RSpec::Matchers.define :represent_collection_with do |representer|
      match do |operation|
        expect(representer).to receive(:represent).and_return "representation"
        expect(operation.call.as_json).to eq "representation"
      end

      def supports_block_expectations?
        true
      end
    end

    # expect(Some::Operation).to represent_collection :things, with: Thing::Representer
    RSpec::Matchers.define :represent_collection do |key, options|
      match do |operation|
        representer = options[:with]

        expect(representer).to receive(:represent).and_return "representation"
        expect(operation.call.as_json).to eq key.to_s => "representation"
      end

      def supports_block_expectations?
        true
      end
    end
  end
end
