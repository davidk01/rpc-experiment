require 'msgpack'
require 'socket'
require 'timeout'

# registration server also checks to make sure
# we are up and running so listen for such requests
# and return an "OK" so that we are not taken out
# of the registry
heartbeat_response = "OK"
heartbeat_request_listener = Thread.new do
  puts "Listening for heartbeat requests."
  Socket.tcp_server_loop(3002) do |conn|
    conn.write(heartbeat_response)
    puts "Closing connection heartbeat response connection."
    conn.close
  end
end

# register every X seconds to make sure registration
# server is up and running
registration_thread = Thread.new do
  puts "Starting registration heartbeat."
  loop do
    begin
    Socket.tcp('localhost', 3000) do |conn|
      puts "Registering."
      payload = {
        :fqdn => Socket.gethostbyname(Socket.gethostname).first,
        :agent_dispatch_port => 3001,
        :heartbeat_port => 3002
      }.to_msgpack
      conn.write(payload)
    end
    rescue Errno::ECONNREFUSED
      puts "Registration hearbeat connection was refused."
    end
    sleep 5
  end
end

registration_thread.join
heartbeat_request_listener.join
