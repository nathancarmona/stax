require 'stax/aws/asg'

module Stax
  module Asg
    def self.included(thor)
      thor.desc(:asg, 'ASG subcommands')
      thor.subcommand(:asg, Cmd::Asg)
    end
  end

  module Cmd
    class Asg < SubCommand
      stax_info :status

      COLORS = {
        ## lifecycle states
        Pending: :yellow, InService: :green, Terminating: :red,
        ## health statuses
        Healthy: :green, Unhealthy: :red,
        ## same for asg instances describe
        HEALTHY: :green, UNHEALTHY: :red,
        ## activity status
        Successful: :green, Failed: :red, Cancelled: :red,
        ## instance state
        running: :green, stopped: :yellow, terminated: :red,
      }

      class_option :groups, aliases: '-g', type: :array, default: nil, desc: 'limit ASGs returned by id'

      no_commands do
        def stack_asgs
          a = Aws::Cfn.resources_by_type(my.stack_name, 'AWS::AutoScaling::AutoScalingGroup')
          filter_asgs(a, options[:groups])
        end

        def filter_asgs(asgs, groups)
          return asgs unless groups
          ids = groups.map { |g| prepend(:asg, g) }
          asgs.select { |g| ids.include?(g.logical_resource_id) }
        end
      end

      desc 'ls', 'list ASGs for stack'
      def ls
        print_table Aws::Asg.describe(stack_asgs.map(&:physical_resource_id)).map { |a|
          [
            a.auto_scaling_group_name[0,40],
            a.launch_configuration_name[0,40],
            "#{a.instances.length}/#{a.desired_capacity}",
            "#{a.min_size}-#{a.max_size}",
            a.availability_zones.map{ |az| az[-1,1] }.sort.join(','),
            a.created_time
          ]
        }
      end

      desc 'status', 'status of instances by ASG'
      def status
        stack_asgs.each do |asg|
          debug("ASG status for #{asg.physical_resource_id}")
          print_table Aws::Asg.instances(asg.physical_resource_id).map { |i|
            [
              i.instance_id,
              i.availability_zone,
              color(i.lifecycle_state, COLORS),
              color(i.health_status, COLORS),
              i.launch_configuration_name,
            ]
          }
        end
      end

      desc 'terminate [ID_REGEXES]', 'terminate matching instances'
      method_option :decrement, aliases: '-d', type: :boolean, default: false, desc: 'decrement desired count after terminate'
      def terminate(*ids)
         instances = Aws::Asg.instances(stack_asgs.map(&:physical_resource_id))
         instances.select do |i|
           ids.any? { |id| i.instance_id.match(id) }
         end.each do |i|
           yes?("Terminate #{i.instance_id}?", :yellow) && Aws::Asg.terminate(i.instance_id, options[:decrement])
         end
      end

      desc 'old', 'ASG instances with outdated launch config'
      method_option :terminate, aliases: '-t', type: :boolean, default: false, desc: 'terminate outdated instances'
      method_option :decrement, aliases: '-d', type: :boolean, default: false, desc: 'decrement desired count after terminate'
      def old
        Aws::Asg.describe(stack_asgs.map(&:physical_resource_id)).map do |a|
          Aws::Asg.instances(a.auto_scaling_group_name).select do |i|
            i.launch_configuration_name != a.launch_configuration_name
          end
        end.flatten.tap do |list|
          print_table list.map { |i| [i.instance_id, i.auto_scaling_group_name, i.launch_configuration_name] }
          if options[:terminate]
            list.each do |i|
              yes?("Terminate #{i.instance_id}?", :yellow) && Aws::Asg.terminate(i.instance_id, options[:decrement])
            end
          end
        end
      end

      desc 'scale', 'ASG scale instance count'
      method_option :desired_capacity, aliases: '-d', type: :numeric, default: nil, desc: 'set desired instance count'
      method_option :min_size,         aliases: '-m', type: :numeric, default: nil, desc: 'set minimum capacity'
      method_option :max_size,         aliases: '-M', type: :numeric, default: nil, desc: 'set maximum capacity'
      def scale
        opt = options.slice(*%w[desired_capacity min_size max_size])
        fail_task('No change requested') if opt.empty?
        stack_asgs.each do |a|
          debug("Scaling to #{opt} for #{a.logical_resource_id} #{a.physical_resource_id}")
          Aws::Asg.update(a.physical_resource_id, opt)
        end
      end

    end
  end
end