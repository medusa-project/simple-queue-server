require_relative 'amqp_base'
require 'march_hare'
require 'retryable'
require 'timeout'
require 'openssl'

class SimpleQueueServer::Messenger::AmqpJava < SimpleQueueServer::Messenger::AmqpBase

  def start_connection(connection_params)
    self.connection = MarchHare.connect(connection_params)
  end

  def read_incoming_message
    metadata, request = self.incoming_queue.pop
    request
  end

  def amqp_error_class
    MarchHare::Exception
  end

end