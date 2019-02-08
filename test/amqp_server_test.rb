require_relative 'test_helper'
require_relative 'doubling_server'

class AmqpServerTest < Minitest::Test

  def setup
    @server = DoublingServer.new(config_file: config_file)
    @messenger = @server.messenger
    @messenger.purge_queues
  end

  def teardown
    @server.close_messenger
  end

  def config_file
    File.join(File.dirname(__FILE__), 'amqp_doubling_config.yml')
  end

  def amqp_connection
    @server.connection
  end

  def channel
    @channel = amqp_connection.create_channel
  end

  def incoming_queue
    @messenger.incoming_queue
  end

  def outgoing_queue
    @messenger.outgoing_queue
  end

  def get_return_message
    #sleep a bit to make sure message has time to get into the queue
    sleep 0.1
    if RUBY_PLATFORM == 'java'
      metadata, payload = outgoing_queue.pop
    else
      delivery_information, properties, payload = outgoing_queue.pop
    end
    JSON.parse(payload)
  end

  def send_message(message, jsonize: true)
    message = message.to_json if jsonize
    incoming_queue.channel.default_exchange.publish(message, routing_key: incoming_queue.name, persistent: true)
    #give a little bit of time to make sure the message appears before trying to process it
    sleep 0.1
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

end