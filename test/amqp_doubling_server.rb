require_relative '../lib/simple_amqp_server'

class AmqpDoublingServer < SimpleAmqpServer::Base

  def handle_double_request(interaction)
    number = interaction.request_parameter('value')
    interaction.succeed(value: number * 2)
  end

end