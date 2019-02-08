require_relative '../messenger'
class SimpleAmqpServer::Messenger::Base

  attr_accessor :logger, :config

  def initialize(logger, config)
    self.config = config
    self.logger = logger
  end

end