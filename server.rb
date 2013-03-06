require 'msgpack'
require 'socket'
require 'thread'
require 'resolv'
require 'resolv-replace'
require 'nio'

# die as soon as possible
Thread.abort_on_exception = true

module ServerRegistrationHearbeatStateMachine
	# keep track of agents
	@registry_lock = Mutex.new
	@registry = {}
	@heartbeat_selector = NIO::Selector.new
	
	def self.start
		start_registration_listener; start_heartbeat_select_loop; start_culling_loop
	end
	
	# set up registration handling
	def self.start_registration_listener
		registration_thread = Thread.new do
		  Socket.tcp_server_loop(3000) do |conn|
			puts "Listening for registration requests."
			Thread.new do
			  puts "Handling registration request."
			  registration_handler(conn)
			end
		  end
		end
	end
	
	# keep re
	def self.start_heartbeat_select_loop
		Thread.new do 
			loop { @heartbeat_selector.select {|m| m.value.call} }
		end
	end
	
	# handle registration requests
	def self.registration_handler(connection)
		payload = MessagePack.unpack(connection.read)
		payload["connection"] = connection
		@registry_lock.synchronize do
			puts "Registering #{payload["fqdn"]}."
			@registry[payload["fqdn"]] = payload
		end
		# add heartbeat connection to NIO select loop
		heartbeat_monitor = @heartbeat_selector.register(connection, :r)
		heartbeat_monitor.value = proc do
			heartbeat = heartbeat_monitor.io.gets
			if heartbeat == "OK"
				puts "#{payload["fqdn"]} still chugging along."
				payload["heartbeat_timestamp"] = Time.now.to_i
			else
				puts "Something went wrong with #{payload["fqdn"]}."
			end
		end
	end
	
	# every 2 minutes go through the list of registered
	# agents and verify that they are up
	def self.start_culling_loop
		Thread.new do
			loop do
				sleep 120
				puts "Culling registrants."
				now = Time.now.to_i
				@registry_lock.synchronize do
					need_to_die = []
					# collect who needs to die
					@registry.each do |fqdn, data|
						if now - data["heartbeat_timestamp"] > 5 * 60
							puts "#{fqdn} hasn't sent a heartbeat in more than 5 minutes."
							puts "Removing #{fqdn} from registry."
							need_to_die << fqdn
						else
							puts "#{fqdn} is chugging along."
						end
					end
					# unregister, close, delete
					need_to_die.each do |fqdn|
						conn = @registry[fqdn]["connection"]
						@heartbeat_selector.deregister(conn)
						conn.close; @registry.delete(fqdn)
					end
				end
			end
		end
	end
end

ServerRegistrationHearbeatStateMachine.start
sleep