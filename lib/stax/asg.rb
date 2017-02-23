require 'awful/auto_scaling'

module Stax
  module Asg
    def self.included(thor)     # magic to make mixins work in Thor
      thor.class_eval do        # ... so magical

        class_option :groups, aliases: '-g', type: :array, default: nil, desc: 'limit ASGs returned by id'

        no_commands do
          def auto_scaling_groups
            cf(:resources, [stack_name], type: ['AWS::AutoScaling::AutoScalingGroup'], quiet: true).tap do |asgs|
              if options[:groups]
                ids = options[:groups].map { |group| prepend(:asg, group) }
                asgs.select! { |g| ids.include?(g.logical_resource_id) }
              end
            end
          end

          def auto_scaling_instances
            asg(:instances, auto_scaling_groups.map(&:physical_resource_id), describe: true, quiet: true)
          end
        end

        desc 'scale', 'scale number of instances in ASGs for stack'
        method_option :desired, aliases: '-d', type: :numeric, default: 4,   desc: 'Desired instance count for each ASG'
        def scale
          auto_scaling_groups.each do |asg|
            id = asg.physical_resource_id
            debug("Scaling to #{options[:desired]} instance(s) for #{id}")
            asg(:update, [id], desired_capacity: options[:desired])
          end
        end

        desc 'old', 'list or terminate old instances from ASGs'
        method_option :terminate, aliases: '-t', default: false, desc: 'terminate old instances'
        def old
          verb = options[:terminate] ? 'Terminating' : 'Listing'
          debug("#{verb} out-of-date instances in autoscaling groups")
          asgs = auto_scaling_groups.map(&:physical_resource_id)
          asg(:old_instances, asgs, terminate: options[:terminate])
        end

      end
    end
  end
end