module SmashTheState
  class Operation
    module DryRun
      class Builder
        attr_reader :wet_sequence, :dry_sequence

        def initialize(wet_sequence)
          @wet_sequence = wet_sequence
          @dry_sequence = Operation::Sequence.new
        end

        def step(step_name, &block)
          referenced_step = wet_sequence.step_for_name(step_name)

          if referenced_step.nil?
            raise "dry run sequence referred to unknown step " \
                  "#{step_name.inspect}. make sure to define " \
                  "your dry run sequence last, after all your steps are defined"
          end

          implementation = block || referenced_step.implementation

          dry_sequence.add_step(
            step_name,
            side_effect_free: true,
            &implementation
          )
        end
      end

      def dry_run(params = {})
        # if an explicit dry run sequence has been specified, use it. otherwise run the
        # main sequence in "side-effect free mode"
        seq = dry_run_sequence || sequence.side_effect_free
        run_sequence(seq, params)
      end
      alias dry_call dry_run

      def dry_run_sequence(&block)
        return @dry_run_sequence unless block_given?

        dry_run_builder = DryRun::Builder.new(sequence).tap do |builder|
          builder.instance_eval(&block)
        end

        @dry_run_sequence = dry_run_builder.dry_sequence
      end
    end
  end
end
