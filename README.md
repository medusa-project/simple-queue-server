[![Build Status](https://travis-ci.org/medusa-project/simple-amqp-server-jruby.svg?branch=master)](https://travis-ci.org/medusa-project/simple-amqp-server-jruby)

# SimpleAmqpServer

This gem makes it easy to put up a server listening and responding to requests via AMQP. Simply subclass SimpleAmqpServer::Base,
configure, follow the conventions for messages, and add handlers for each action you want to handle.

As things are now this is a simple, single-threaded server. It wouldn't be that hard to extend it for additional
functionality if desired, or multiple copies can be run with no modification. However, this original design
is primarily intended for use in a server that is fairly mildly used.

JRuby is needed for use of this gem.

## Installation

Add this line to your application's Gemfile:

    gem 'simple-amqp-server', git: 'https://github.com/medusa-project/simple-amqp-server-jruby.git'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install simple_amqp_server

## Usage

### Configuration

When instantiating the server do so with the path to a YAML configuration file:

    MyServer.new(config_file: 'path/to/config')
    
The config file has three required sections:

* server
    - name - required. Simply a string naming the server. This will be used to create a log directory, etc.
    - sleep_on_empty - optional. The number of seconds to sleep when the incoming queue is empty. Default 60.

* amqp
    - incoming_queue - required. The name of the amqp queue off of which the server takes messages to service.
    - outgoing_queue - optional. The name of the amqp queue to which the server sends response messages. If this
     is not provided then no outgoing messages will be sent.
    - connection - optional. This hash is passed in its entirety to the March Hare gem for connection to AMQP. If it is
     blank or any entries are blank they simply get the defaults. Note that March Hare expects this hash to have 
      symbols for keys, so reflect that in the YAML.
      
* log - note that for an optional log message to be generated the level must be high enough *and* the appropriate 
flag must be turned on.
    - level - optional, default :info. The base logging level
    - show_requests - optional, default false. Whether to record incoming messages in the log.
    - show_responses - optional, default false. Whether to record outgoing messages in the log.
      
A simple config file might look like:
      
    server:
      name: test_server
      sleep_on_empty: 5
    amqp:
      incoming_queue: in_to_test
      outgoing_queue: out_of_test
      connection:
        :port: 5672  
    log:
      level: :info
  
You may add any additional stanzas or keys to the config file that you like as required. The SimpleAmqpServer::Config 
class loads the entire file and stores it for the servers use, and also provides a few convenience methods for getting
at values.

If you want a specialized config class you can override the config_class method of SimpleAmqpServer::Base and 
subclass SimpleAmqpServer::Config. 
 
Note that both queues are persistent (the server will make them if they don't already exist) and outgoing messages
 are also persistent. 

### Message protocol

Part of the reason that this is simple is that the incoming and outgoing messages obey some simple conventions. 
Incoming messages are JSON objects that the server parses into a hash and deals with. Outgoing messages are also
JSON objects, although when implementing actions one just creates a hash as part of the response object. The server
automatically converts it. 

#### Incoming messages

  * action - required. What you want the server to do. This can be any string. The server must implement handlers
  for each action it is going to handle.
  * parameters - required. A sub-object that has the information the server needs to service the request. This can 
  be whatever you need.
  * pass_through - optional. A sub-object that the server will pass back unchanged as part of the response message. 
   This is useful, for example, for identifying what on the other side requested the action so that it can deal with
   the results.

#### Outgoing messages

The return message may contain any of the following:

  * action - the action the client requested of the server
  * status - either 'success' or 'failure', with the obvious meaning
  * error_message - in the event of failure a short message about the failure. There are some standard messages for
  things like being unable to parse the incoming message or not finding the requested action.
  * parameters - anything else that the server wants to return to the client
  * pass_through - whatever the client originally sent in its pass_through. An empty hash if this was not provided.
  
In the event that the server was unable to parse the incoming message it obviously can't return things like the action 
or pass_through, so instead it returns the entire original request as 'raw_request' in the parameters.

### Implementing server functionality

For each action you want to handle implement a handle_<action>_request(interaction) method. The Interaction class
encapsulates the request and response; if you want a specialized class you can override interaction_class in your
server class and subclass SimpleAmqpServer::Interaction.

Your handler takes the information in the request in the interaction and uses that to service the request. It fills out
the necessary return information in the response in the interaction. After the handler is exited the server will use that 
information to formulate the response message.

The following is a simple example that takes the 'number' parameter and returns its square as 'square'

    require_relative 'simple_amqp_server'
    
    class TestServer < SimpleAmqpServer::Base
    
      def handle_square_request(interaction)
        number = interaction.request_parameter('number')
        interaction.succeed(square: number * number)
      end
    
    end

### Running, logging, recovery, etc.

To use, instantiate the server with the config file and run it:

    MyServer.new(config_file: 'path/to/config').run

The server first services any saved requests (see below) then starts working on the incoming queue. It pulls one request,
services it, and repeats. If there are no requests when it tries to pull then it sleeps for a while and tries again.

Logging is done into 'log' subdirectory in a file named after the server name.

Each request is assigned a UUID that is shown in the log.

The server has a logger object that can be used in subclasses for additional logging.

Sending the server a USR2 signal will make it toggle between shutting down after servicing the current request and not.
Of course it starts out not doing that. This is intended to enable you to shut it down gracefully if it is in the middle
of serving a long running request.

#### Saved requests

Our use case involves potentially long running requests that can be harmlessly retried. The server design reflects this.
When a request is read from the message queue it is written to the file system under the 'run' directory. If the request
is completed (whether by a successful completion of the request or a response showing some sort of error) then this is 
deleted. However, if the server is otherwise interrupted (e.g. you kill its process, the machine crashes, etc.) then the
request remains on the file system. When the server is restarted it first takes any requests on the filesystem and services
them before looking at the queue. (If you don't want this to happen, remove these before restarting. We may make this
configurable in the future.)


