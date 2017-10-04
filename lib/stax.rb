require 'thor'

require 'stax/aws/sdk'
require 'stax/aws/cfn'

require 'stax/staxfile'
require 'stax/base'
require 'stax/git'
require 'stax/cli'
require 'stax/stack'
require 'stax/stack/cfn'
require 'stax/stack/crud'
require 'stax/stack/parameters'
require 'stax/stack/outputs'
require 'stax/subcommand'

require 'stax/mixin/ec2'
require 'stax/mixin/alb'
require 'stax/mixin/elb'
require 'stax/mixin/sg'
require 'stax/mixin/s3'
require 'stax/mixin/asg'
require 'stax/mixin/ecs'
require 'stax/mixin/sqs'
require 'stax/mixin/kms'
require 'stax/mixin/ssm'
require 'stax/mixin/keypair'

require 'stax/cfer'