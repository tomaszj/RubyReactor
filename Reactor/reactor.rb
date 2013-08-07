#!/usr/bin/env ruby -wKU
# Written with version 1.9.3 in mind

require "socket"

# Config
port = 2000

# Reactor class
class Reactor
  def initialize(socket)
    @server_socket = socket
    @sockets = [socket]

    # Set up the event handlers map
    @event_handlers = {
      :accept_event => {},
      :read_event => {},
      :close_event => {}
    }
  end

  # Registers a handler for an event for a given socket
  def register_for_event(handler, socket, event)
    @event_handlers[event][socket] = handler

    @sockets ||= [socket]
  end

  # Unregisters a handler from events
  def unregister(handler, socket)
    @event_handlers[:read_event].delete(socket)
    @event_handlers[:close_event].delete(socket)
    @sockets.delete(socket)
  end

  def handle_events
    # Wait for the socket event
    r = IO.select(@sockets)[0]

    # Determine the event type and handle it
    r.each do |socket|

      # Perform demultiplexing and dispatch of the event
      event_type = determine_event_type(socket)

      # Determine the handler and handle the event
      handler = @event_handlers[event_type][socket]
      handler.handle_event(event_type)
    end
  end

  def determine_event_type(socket)
    if socket == @server_socket
      :accept_event
    elsif socket.eof?
      :close_event
    else
      :read_event
    end
  end
end

# Accepts connections
class ConnectionAcceptor
  def initialize(socket, reactor)
    @socket = socket
    @reactor = reactor

    reactor.register_for_event(self, socket, :accept_event)
  end

  def handle_event(type)
    raise "ConnectionAcceptor: Can't handle #{type}" if type != :accept_event

    client_socket = @socket.accept
    EchoHandler.new(client_socket, @reactor)
  end
end

# Service handler which performs a simple echo upon each line
class EchoHandler
  def initialize(socket, reactor)
    @socket = socket
    @reactor = reactor

    reactor.register_for_event(self, socket, :read_event)
    reactor.register_for_event(self, socket, :close_event)
  end

  def handle_event(type)
    if type == :read_event
      input = @socket.gets
      @socket.puts "Echo: #{input}"
    elsif type == :close_event
      @reactor.unregister(self, @socket)
      @socket.close
    else
      raise "ConnectionAcceptor: Can't handle #{type}"
    end
  end
end

# Server with a loop
class EchoServer
  def initialize(port)
    @server_socket = TCPServer.new port

    p "Starting Echo TCP server at localhost:#{port}"
  end

  def start
    # Initialize the reactor
    reactor = Reactor.new @server_socket
    ConnectionAcceptor.new(@server_socket, reactor)
    loop { reactor.handle_events }
  end
end


# --- Start of the script ---

echo_server = EchoServer.new port
echo_server.start
