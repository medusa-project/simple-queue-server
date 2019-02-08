require_relative '../messenger'
class SimpleAmqpServer::Messenger::Base

  attr_accessor :logger

  def initialize(logger)
    self.logger = logger
  end

end