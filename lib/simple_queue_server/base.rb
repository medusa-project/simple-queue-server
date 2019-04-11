require 'logger'
require 'fileutils'
require 'config'
require_relative 'interaction'
require_relative 'messenger/factory'

module SimpleQueueServer
  class Base < Object

    attr_accessor :logger, :halt_before_processing, :messenger

    def initialize(args = {})
      initialize_config(args[:config_file])
      initialize_logger
      self.messenger = SimpleQueueServer::Messenger::Factory.new.create(self.logger)
      self.halt_before_processing = false
    end

    def interaction_class
      Interaction
    end

    def initialize_config(config_file)
      Config.load_and_set_settings(config_file)
    end

    def initialize_logger
      [self.log_directory, self.run_directory, self.request_directory].each { |directory| FileUtils.mkdir_p(directory) }
      self.logger = Logger.new(self.log_file)
      self.logger.level = Settings.log.level || :info
      self.logger.info 'Starting server'
    end

    def log_directory
      'log'
    end

    def log_file
      File.join('log', "#{Settings.server.name}.log")
    end

    def run_directory
      'run'
    end

    def request_directory
      File.join('run', "#{Settings.server_name}_active_requests")
    end

    def run
      Kernel.at_exit do
        self.logger.info 'Stopping server'
      end
      Kernel.trap('USR2') do
        self.halt_before_processing = !self.halt_before_processing
        logger_tee "Server will halt before processing next job: #{self.halt_before_processing}"
      end
      service_saved_requests
      while true do
        service_incoming_request_or_sleep
        break if self.halt_before_processing
      end
      messenger.close
    rescue Exception => e
      logger.error "Unexpected error: #{e}. Exiting"
    end

    def shutdown
      logger_tee "Halting server before processing request."
      exit 0
    end

    def logger_tee(message)
      logger.info message
      puts message
    end

    def sleep_on_empty_time
      Settings.server.sleep_on_empty || 60
    end

    def service_saved_requests
      Dir[File.join(self.request_directory, '*-*')].each do |file|
        interaction = self.interaction_class.new(File.read(file), File.basename(file))
        self.logger.info "Restarting Request: #{interaction.uuid}\n#{interaction.raw_request}"
        service_request(interaction)
        shutdown if halt_before_processing
      end
    end

    def service_incoming_request_or_sleep
      request = messenger.get_incoming_request
      if request
        self.service_incoming_request(request)
      else
        sleep self.sleep_on_empty_time
      end
    end

    def service_incoming_request(request)
      interaction = self.interaction_class.new(request)
      logger.info "Started Request: #{interaction.uuid}\n#{request}" if Settings.log.show_requests
      persist_request(interaction)
      service_request(interaction)
      shutdown if halt_before_processing
    end

    def persist_request(interaction)
      FileUtils.mkdir_p(request_directory)
      File.open(File.join(request_directory, interaction.uuid), 'w') { |f| f.puts interaction.raw_request }
    end

    def unpersist_request(interaction)
      file = File.join(request_directory, interaction.uuid)
      FileUtils.rm(file) if File.exists?(file)
    end

    def service_request(interaction)
      if interaction.failed_request_parse?
        logger.error "Bad Request: #{interaction.raw_request}"
      else
        dispatch_and_handle_request(interaction)
      end
      unpersist_request(interaction)
      logger.info "Returning: #{interaction.response.to_json}" if Settings.log.show_responses
      messenger.send_outgoing_message(interaction.response.to_json)
      logger.info "Finished Request: #{interaction.uuid}"
    end

    def dispatch_and_handle_request(interaction)
      handler_name = "handle_#{interaction.action}_request"
      if respond_to?(handler_name)
        send(handler_name, interaction)
      else
        interaction.fail_unrecognized_action
      end
    rescue Exception => e
      logger.error "Unknown Error: #{e.to_s}"
      logger.error "Backtrace: #{e.backtrace}"
      interaction.fail_unknown
    end

    def close_messenger
      self.messenger.close
    end

  end

end
