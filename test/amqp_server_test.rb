require_relative 'test_helper'
require_relative 'amqp_doubling_server'

class AmqpServerTest < Minitest::Test

  def setup
    delete_queues
    create_queues
    @server = AmqpDoublingServer.new(config_file: config_file)
  end

  def teardown
    @connection.close
    @server.close_amqp
  end

  def config_file
    File.join(File.dirname(__FILE__), 'amqp_doubling_config.yml')
  end

  def amqp_connection
    @connection ||= MarchHare.connect
  end

  def channel
    @channel = amqp_connection.create_channel
  end

  def delete_queues
    incoming_queue.delete
    outgoing_queue.delete
  end

  def create_queues
    incoming_queue
    outgoing_queue
  end

  def incoming_queue
    channel.queue(incoming_queue_name, durable: true)
  end

  def outgoing_queue
    channel.queue(outgoing_queue_name, durable: true)
  end

  def test_doubling
    number = rand(20)
    message = {action: 'double', parameters: {value: number}, pass_through: {id: 'someid'}}
    incoming_queue.channel.default_exchange.publish(message.to_json, routing_key: incoming_queue.name, persistent: true)
    @server.service_incoming_request_or_sleep
    metadata, payload = outgoing_queue.pop
    return_message = JSON.parse(payload)
    assert_equal 'double', return_message['action']
    assert_equal 'success', return_message['status']
    assert_equal number * 2, return_message['parameters']['value']
    assert_equal 'someid', return_message['pass_through']['id']
  end

  private

  def outgoing_queue_name
    'simple_amqp_server_test_out'
  end

  def incoming_queue_name
    'simple_amqp_server_test_in'
  end

end