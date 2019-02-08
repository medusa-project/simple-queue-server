# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'simple_queue_server/version'

Gem::Specification.new do |spec|
  spec.name          = "simple-queue-server"
  spec.version       = SimpleQueueServer::VERSION
  spec.authors       = ["Howard Ding"]
  spec.email         = ["hding2@illinois.edu"]
  spec.summary       = %q{Simple way to make a server listening to AMQP or SQS}
  spec.description   = %q{Follow some simple conventions to make a simple AMQP or SQS server.}
  spec.homepage      = "https://github.com/medusa-project/simple-queue-server"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  #I'm not sure this will work, but given that we will always install this directly from the git repo, it might
  # If the gem were prebuilt I don't think it would.
  spec.add_runtime_dependency 'bunny'
  spec.add_runtime_dependency "logging"
  spec.add_runtime_dependency "uuid"
  spec.add_runtime_dependency "retryable"
  spec.add_runtime_dependency "aws-sdk-sqs"
  spec.add_runtime_dependency 'config'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"

end
