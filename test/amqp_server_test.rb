require_relative 'test_helper'
require_relative 'amqp_doubling_server'

class AmqpServerTest < Minitest::Test

  def setup
    ensure_queues
    purge_queues
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
    @connection = Bunny.new
    @connection.start
  end

  def channel
    @channel = amqp_connection.create_channel
  end

  def purge_queues
    incoming_queue.purge
    outgoing_queue.purge
  end

  def ensure_queues
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
    #sleep a bit to make sure message has time to get into the queue
    sleep 0.1
    delivery_information, properties, payload = outgoing_queue.pop
    JSON.parse(payload)
  end

  def test_doubling
    number = rand(20)
    message = {action: 'double', parameters: {value: number}, pass_through: {id: 'someid'}}
    send_message(message)
    @server.service_incoming_request_or_sleep
    return_message = get_return_message
    assert_equal 'double', return_message['action']
    assert_equal 'success', return_message['status']
    assert_equal 'someid', return_message['pass_through']['id']
    assert_equal number * 2, return_message['parameters']['value']
  end

  def send_message(message, jsonize: true)
    message = message.to_json if jsonize
    incoming_queue.channel.default_exchange.publish(message, routing_key: incoming_queue.name, persistent: true)
    #give a little bit of time to make sure the message appears before trying to process it
    sleep 0.1
  end

  def test_unrecognized_action
    message = {action: 'triple', parameters: {value: 0}, pass_through: {id: 'someid'}}
    send_message(message)
    @server.service_incoming_request_or_sleep
    return_message = get_return_message
    assert_equal 'triple', return_message['action']
    assert_equal 'failure', return_message['status']
    assert_equal 'someid', return_message['pass_through']['id']
    assert_equal 'Unrecognized Action', return_message['message']
  end

  def test_expected_failure
    message = {action: 'double', parameters: {value: 'joe'}, pass_through: {id: 'someid'}}
    send_message(message)
    @server.service_incoming_request_or_sleep
    return_message = get_return_message
    assert_equal 'double', return_message['action']
    assert_equal 'failure', return_message['status']
    assert_equal 'someid', return_message['pass_through']['id']
    assert_equal 'Invalid argument', return_message['message']
  end

  def test_invalid_request
    message = "Not JSON"
    send_message(message, jsonize: false)
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