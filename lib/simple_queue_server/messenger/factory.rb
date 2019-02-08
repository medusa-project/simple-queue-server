require_relative 'amqp'
require_relative 'sqs'

class SimpleQueueServer::Messenger::Factory

  def create(logger)
    if Settings.amqp
      SimpleQueueServer::Messenger::Amqp.new(logger)
    elsif Settings.sqs
      SimpleQueueServer::Messenger::Sqs.new(logger)
    else
      raise "No configuration for a known messenger."
    end

  end
end
