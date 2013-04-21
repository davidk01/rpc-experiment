require 'socket'
require 'json'

['../actionpayload', '../fiberdsl'].each do |f|
  path = File.absolute_path(File.dirname(__FILE__) + '/' + f)
  puts "Requiring: #{path}."
  require path
end

class Client

  class Agent
    
    def initialize(fqdn, port); @fqdn, @port = fqdn, port; end
    
    # open a connection to the dispatch port and send the request
    def act(plugin, action, arguments = {})
      TCPSocket.open(@fqdn, @port) do |sock|
        payload =  ActionPayload.new("plugin" => plugin, "action" => action, "arguments" => arguments)
        sock.puts payload.serialize
        reader = PartialReaderDSL::FiberReaderMachine.protocol(true) do
          consume(4) { |buff| buff.unpack("*i")[0] }
          consume { |buff| JSON.parse buff }
        end
        reader.call(sock)[0]
      end
    end

  end

  attr_reader :agents

  def initialize(opts = {})
    [:registration_server, :query_port].each do |e|
      raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
    end
    TCPSocket.open(opts[:registration_server], opts[:query_port]) do |sock|
      payload = {"request_type" => "agent_discovery"}.to_json
      sock.write [payload.length].pack("*i") + payload
      reader = PartialReaderDSL::FiberReaderMachine.protocol(true) do
        consume(4) { |buff| buff.unpack("*i")[0] }
        consume { |buff| JSON.parse(buff)["agents"] }
      end
      @agents = reader.call(sock)[0].map { |agent_data| Agent.new(*agent_data) }
    end
  end
  
end
