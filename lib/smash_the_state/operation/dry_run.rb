module SmashTheState
  class Operation
    module DryRun
      class Builder
        attr_reader :wet_sequence, :dry_sequence

        def initialize(wet_sequence)
          @wet_sequence = wet_sequence
          @dry_sequence = Operation::Sequence.new

          # in the case of a dynamic schema, front-load it as the first step
          dynamic_schema_step = @wet_sequence.dynamic_schema_step
          unless dynamic_schema_step.nil?
            step(dynamic_schema_step.name, &dynamic_schema_step.implementation)
          end
        end

        def step(step_name, &block)
          referenced_steps = wet_sequence.steps_for_name(step_name)

          if block
            add_dry_run_step(step_name, &block)
            return
          end

          if referenced_steps.empty?
            raise "dry run sequence referred to unknown step " \
                  "#{step_name.inspect}. make sure to define " \
                  "your dry run sequence last, after all your steps are defined"
          end

          referenced_steps.each do |referenced_step|
            # we're gonna copy the implementation verbatim but add a new step marked as
            # side-effect-free, because if the step was added to the dry run sequence it
            # must be assumed to be side-effect-free
            add_dry_run_step(step_name, &referenced_step.implementation)
          end
        end

        private

        def add_dry_run_step(step_name, &block)
          if step_name == :validate
            dry_sequence.add_validation_step(&block)
          else
            dry_sequence.add_step(step_name, side_effect_free: true, &block)
          end
        end
      end

      # dry runs are meant to produce the same types of output as a normal call/run,
      # except they should not produce any side-effects (writing to a database, etc)
      def dry_run(params = {})
        # if an valid dry run sequence has been specified, use it. otherwise run the main
        # sequence in "side-effect free mode" (filtering out steps that cause
        # side-effects)
        seq = if dry_run_sequence?
                dry_run_sequence
              else
                sequence.side_effect_free
              end

        run_sequence(seq, params)
      end
      alias dry_call dry_run

      def dry_run_sequence(&block)
        # to keep the operation code cleaner, we will delegate dry run sequence building
        # to another module (allows us to have a method named :step without having to make
        # the operation :step method super complicated)
        @dry_run_builder ||= DryRun::Builder.new(sequence)

        # if a block is given, we want to evaluate it with the builder
        @dry_run_builder.instance_eval(&block) if block_given?

        # the builder will produce a side-effect-free sequence for us
        @dry_run_builder.dry_sequence
      end

      # a valid dry run sequence should have at least one step. if there isn't at least
      # one step, the dry run sequence is basically a no-op
      def dry_run_sequence?
        !dry_run_sequence.steps.empty?
      end
    end
  end
end
