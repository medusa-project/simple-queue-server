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
    @server.close_messenger
  end

  def config_file
    File.join(File.dirname(__FILE__), 'amqp_doubling_config.yml')
  end

  def amqp_connection
    if RUBY_PLATFORM == 'java'
      @connection ||= MarchHare.connect
    else
      @connection = Bunny.new
      @connection.start
    end
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

  def get_return_message
    if RUBY_PLATFORM == 'java'
      metadata, payload = outgoing_queue.pop
    else
      delivery_information, properties, payload = outgoing_queue.pop
    end
    JSON.parse(payload)
  end

  def test_doubling
    number = rand(20)
    message = {action: 'double', parameters: {value: number}, pass_through: {id: 'someid'}}
    incoming_queue.channel.default_exchange.publish(message.to_json, routing_key: incoming_queue.name, persistent: true)
    @server.service_incoming_request_or_sleep
    return_message = get_return_message
    assert_equal 'double', return_message['action']
    assert_equal 'success', return_message['status']
    assert_equal 'someid', return_message['pass_through']['id']
    assert_equal number * 2, return_message['parameters']['value']
  end

  def test_unrecognized_action
    message = {action: 'triple', parameters: {value: 0}, pass_through: {id: 'someid'}}
    incoming_queue.channel.default_exchange.publish(message.to_json, routing_key: incoming_queue.name, persistent: true)
    @server.service_incoming_request_or_sleep
    return_message = get_return_message
    assert_equal 'triple', return_message['action']
    assert_equal 'failure', return_message['status']
    assert_equal 'someid', return_message['pass_through']['id']
    assert_equal 'Unrecognized Action', return_message['message']
  end

  def test_expected_failure
    message = {action: 'double', parameters: {value: 'joe'}, pass_through: {id: 'someid'}}
    incoming_queue.channel.default_exchange.publish(message.to_json, routing_key: incoming_queue.name, persistent: true)
    @server.service_incoming_request_or_sleep
    return_message = get_return_message
    assert_equal 'double', return_message['action']
    assert_equal 'failure', return_message['status']
    assert_equal 'someid', return_message['pass_through']['id']
    assert_equal 'Invalid argument', return_message['message']
  end

  def test_invalid_request
    message = "Not JSON"
    incoming_queue.channel.default_exchange.publish(message, routing_key: incoming_queue.name, persistent: true)
    @server.service_incoming_request_or_sleep
    return_message = get_return_message
    assert_equal message, return_message['raw_request']
    assert_equal 'Invalid Request', return_message['message']
  end

  private

  def outgoing_queue_name
    'simple_amqp_server_test_out'
  end

  def incoming_queue_name
    'simple_amqp_server_test_in'
  end

end