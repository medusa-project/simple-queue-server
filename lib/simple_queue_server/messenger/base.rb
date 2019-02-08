require_relative '../messenger'
class SimpleQueueServer::Messenger::Base

  attr_accessor :logger

  def initialize(logger)
    self.logger = logger
  end

end