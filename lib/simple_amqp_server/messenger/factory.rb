if RUBY_PLATFORM == 'java'
  require_relative 'amqp_jruby'
else
  require_relative 'amqp_mri'
end
require_relative 'sqs'

class SimpleAmqpServer::Messenger::Factory

  def create(logger, config)
    if config.amqp
      if RUBY_PLATFORM == 'java'
        SimpleAmqpServer::Messenger::AmqpJruby.new(logger, config)
      else
        SimpleAmqpServer::Messenger::AmqpMri.new(logger, config)
      end
    elsif config.sqs

    else
      raise "No configuration for a known messenger."
    end
  end

end