require_relative 'base'
require 'aws-sdk-sqs'

class SimpleAmqpServer::Messenger::Sqs < SimpleAmqpServer::Messenger::Base

  attr_accessor :client, :incoming_queue_url, :outgoing_queue_url

  def initialize(logger, config)
    super
    self.client = Aws::SQS::Client.new(config.sqs['connection'])
    ensure_queues
  end

  def ensure_queues
    incoming_name = config.sqs['incoming_queue']
    outgoing_name = config.sqs['outgoing_queue']
    self.incoming_queue_url, self.outgoing_queue_url = [incoming_name, outgoing_name].collect do |name|
      url = begin
        client.get_queue_url(queue_name: name).queue_url
      rescue Aws::SQS::Errors::NonExistentQueue
        client.create_queue(queue_name: name).queue_url
      end
    end
  end

  def close
    #noop
  end

  def get_incoming_request
    messages = client.receive_message(queue_url: incoming_queue_url, max_number_of_messages: 1).messages
    message = messages[0]
    return nil unless message
    client.delete_message(queue_url: incoming_queue_url, receipt_handle: message.receipt_handle)
    message.body
  end

  def send_outgoing_message(message)
    client.send_message(queue_url: outgoing_queue_url, message_body: message)
  end

  #This is really only intended for testing. We avoid the purge_queue method, which limited to once a minute,
  # and simply get and delete all the messages
  def purge_queues
    [incoming_queue_url, outgoing_queue_url].each do |queue_url|
      while true
        messages = client.receive_message(queue_url: queue_url, max_number_of_messages: 10).messages
        break unless messages.first
        messages.each do |message|
          client.delete_message(queue_url: queue_url, receipt_handle: message.receipt_handle)
        end
      end
    end
  end

end