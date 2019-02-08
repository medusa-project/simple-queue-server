require_relative 'amqp'
require_relative 'sqs'

class SimpleAmqpServer::Messenger::Factory

  def create(logger)
    if Settings.amqp
      SimpleAmqpServer::Messenger::Amqp.new(logger)
    elsif Settings.sqs
      SimpleAmqpServer::Messenger::Sqs.new(logger)
    else
      raise "No configuration for a known messenger."
    end

  end
end
