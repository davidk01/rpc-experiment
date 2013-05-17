require 'socket'
require 'json'

['../actionpayload', '../fiberdsl'].each do |f|
  path = File.expand_path(File.dirname(__FILE__) + '/' + f)
  require path
end

class Client

  # just a container for results from a filtring operation
  class FilterResponse
    
    attr_reader :result, :agent

    def initialize(truthy_result, agent)
      @result = truthy_result; @agent = agent
    end

  end

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

  # Get the list of agents from the registration server and initialize
  # the agent objects so that we can make some RPC requests.
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
  
  # Takes a block that gets an agent and then return a truthy value.
  # The agents that have truthy values from the block are kept and
  # the rest are discarded. This is not a destructive operation. The
  # original agents are still kept. The final result is a list of tuples
  # where the first entry is the truthy result of the block and the second
  # element is the agent.
  def filter(&blk)
    # we don't want to start more than 20 threads a time because it is possible
    # to get back thousands of agents from the registration server and starting
    # a thousand threads is not going to be fun for anyone.
    result_slices = @agents.each_slice(20).map do |agents_slice|
      threads = agents_slice.map do |agent| 
        Thread.new { Thread.current[:result] = [blk.call(agent), agent] }
      end
      threads.map {|t| t.join; t[:result]}.select {|res, agent| res}
    end
    result_slices.reduce([]) do |memo, data_slice|
      data_slice.each {|data_item| memo << FilterResponse.new(*data_item)}; memo
    end
  end

end
