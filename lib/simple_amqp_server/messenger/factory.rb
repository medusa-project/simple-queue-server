require_relative 'amqp'
require_relative 'sqs'

class SimpleAmqpServer::Messenger::Factory

  def create(logger, config)
    if config.amqp
      SimpleAmqpServer::Messenger::Amqp.new(logger, config)
    elsif config.sqs

    else
      raise "No configuration for a known messenger."
    end

  end
end
