require_relative 'base'
require 'retryable'
require 'timeout'
require 'openssl'

class SimpleQueueServer::Messenger::AmqpBase < SimpleQueueServer::Messenger::Base

  attr_accessor :connection, :outgoing_queue, :incoming_queue, :channel

  def initialize(logger)
    super
    attempted_retries = 0
    begin
      close
      connection_params = {recover_from_connection_close: true}.merge(Settings.amqp.connection.to_h || {})
      self.logger.info("Trying to connect to AMQP server")
      start_connection(connection_params)
      self.logger.info("Connected to AMQP server")
      self.channel = connection.create_channel
      self.incoming_queue = self.channel.queue(Settings.amqp.incoming_queue, durable: true)
      self.outgoing_queue = self.channel.queue(Settings.amqp.outgoing_queue, durable: true) if Settings.amqp.outgoing_queue
    rescue OpenSSL::SSL::SSLError, Timeout::Error, amqp_error_class => e
      self.logger.error("Error opening amqp connection: #{e}")
      self.logger.error("Backtrace: #{e.backtrace}")
      attempted_retries = attempted_retries + 1
      raise if Settings.amqp.max_connection_retry_errors and attempted_retries > Settings.amqp.max_connection_retry_errors
      sleep_factor = [attempted_retries + 1, 3].min
      sleep 5 ** sleep_factor
      self.logger.error("Retrying")
      retry
    end
  end

  def close
    self.logger.info("Trying to close amqp")
    self.connection.close if self.connection and self.connection.open?
    self.logger.info("Closed amqp") unless self.connection and self.connection.open?
  end

  def get_incoming_request
    Retryable.retryable(tries: 10, sleep: 60, on: [amqp_error_class, Timeout::Error],
                        exception_cb: Proc.new {|e| self.logger.error("Error getting incoming request: #{e}")}) do
      ensure_connection
      read_incoming_message
    end
  end

  def send_outgoing_message(message)
    Retryable.retryable(tries: 10, sleep: 60, on: [amqp_error_class, Timeout::Error],
                        exception_cb: Proc.new {|e| self.logger.error("Error sending outgoing message: #{e}\nMessage: #{message}")}) do
      if self.outgoing_queue
        ensure_connection
        outgoing_queue.channel.default_exchange.publish(message, routing_key: outgoing_queue.name, persistent: true)
      end
    end
  end

  def purge_queues
    [incoming_queue, outgoing_queue].each do |queue|
      queue.purge
    end
  end

  def read_incoming_message
    raise "Subclass responsibility"
  end

  def start_connection(connection_params)
    raise "Subclass responsibility"
  end

  def amqp_error_class
    raise "Subclass responsibility"
  end

  private

  def ensure_connection
    self.initialize(self.logger) unless self.connection and self.connection.open?
  end

end
