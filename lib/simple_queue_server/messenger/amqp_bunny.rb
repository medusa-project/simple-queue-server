require_relative 'amqp_base'
require 'bunny'


class SimpleQueueServer::Messenger::AmqpBunny < SimpleQueueServer::Messenger::AmqpBase

  def start_connection(connection_params)
    self.connection = Bunny.new(connection_params)
    self.connection.start
  end

  def read_incoming_message
    delivery_info, properties, request = self.incoming_queue.pop
    request
  end

  def amqp_error_class
    Bunny::Exception
  end

end