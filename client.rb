require 'msgpack'
require 'resolv'
require 'resolv-replace'
require 'socket'
require 'timeout'

# die as soon as possible
Thread.abort_on_exception = true

module ClientRegistrationHeartbeatStateMachine
	def self.start
		register; establish_heartbeat; monitor_heartbeat; accept_rpc_requests
	end
	
	# keep trying until we successfully register
	def self.register
		begin
			@conn = Socket.tcp('localhost', 3000)
			puts "Registering."
			@conn.write({
				"fqdn" => Socket.gethostbyname(Socket.gethostname).first,
				"agent_dispatch_port" => 3001
			}.to_msgpack)
		rescue Errno::ECONNREFUSED
			puts "Registration connection refused. Retrying."
			retry
		end
	end
	
	# send "OK" every X number of seconds
	def self.establish_heartbeat
		@heartbeat_thread = Thread.new do
      puts "Heartbeat."
			@conn.puts "OK"
			sleep 5
		end
	end
	
	# make sure hearbeat connection is working and take action to
	# correct the error if we can't send the heartbeat
	def self.monitor_heartbeat
		@heartbeat_monitor_thread = Thread.new do
			loop do
				puts "No mitigating action yet."
				sleep 120
			end
		end
	end

  def self.accept_rpc_requests
    puts "Accepting rpc requests."
  end
end

ClientRegistrationHeartbeatStateMachine.start
sleep