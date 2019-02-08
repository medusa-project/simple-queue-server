require_relative '../lib/simple_amqp_server'

class DoublingServer < SimpleAmqpServer::Base

  def handle_double_request(interaction)
    number = interaction.request_parameter('value')
    if number.is_a?(Numeric)
      interaction.succeed(value: number * 2)
    else
      interaction.fail_generic('Invalid argument')
    end
  end

end