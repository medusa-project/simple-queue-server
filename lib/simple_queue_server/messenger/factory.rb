require_relative 'amqp_bunny'
require_relative 'amqp_java' if RUBY_PLATFORM == 'java'
require_relative 'sqs'

class SimpleQueueServer::Messenger::Factory

  def create(logger)
    if Settings.amqp
      if RUBY_PLATFORM == 'java'
        SimpleQueueServer::Messenger::AmqpJava.new(logger)
      else
        SimpleQueueServer::Messenger::AmqpBunny.new(logger)
      end
    elsif Settings.sqs
      SimpleQueueServer::Messenger::Sqs.new(logger)
    else
      raise "No configuration for a known messenger."
    end

  end
end
