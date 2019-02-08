require_relative 'test_helper'
require_relative 'doubling_server'

class SqsServerTest < Minitest::Test

  def setup
    @server = DoublingServer.new(config_file: config_file)
    @messenger = @server.messenger
  end

  def teardown
    @messenger.purge_queues
    @server.close_messenger
  end

  def config_file
    File.join(File.dirname(__FILE__), 'sqs_doubling_config.yml')
  end

  def incoming_queue_url
    @messenger.incoming_queue_url
  end

  def outgoing_queue_url
    @messenger.outgoing_queue_url
  end

  def client
    @messenger.client
  end

  def get_return_message(retries: 10)
    sleep 0.1
    message = client.receive_message(queue_url: outgoing_queue_url, max_number_of_messages: 1).messages.first
    unless message
      return nil if retries.zero?
      return get_return_message(retries: retries - 1)
    end
    client.delete_message(queue_url: outgoing_queue_url, receipt_handle: message.receipt_handle)
    JSON.parse(message.body)
  end

  def send_message(message, jsonize: true)
    message = message.to_json if jsonize
    client.send_message(queue_url: incoming_queue_url, message_body: message)
    sleep 0.2
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

  private


end