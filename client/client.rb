require 'socket'
require 'msgpack'

class Client

  def initialize(opts = {})
    [:registration_server, :query_port].each do |e|
      raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
    end
    Socket.tcp(opts[:registration_server], opts[:query_port]) do |sock|
      payload = {"request_type" => "agent_discovery"}.to_msgpack
      sock.write [payload.length].pack("*i") + payload
      reply_length = sock.read(4).unpack("*i")[0]
      @agents = MessagePack.unpack(sock.read(reply_length))["agents"]
    end
  end

end
