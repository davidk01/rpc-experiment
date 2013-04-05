require 'socket'
require 'msgpack'

payload = {
  :plugin => 'host.discovery',
  :action => 'fact_filter',
  :arguments => {"fact" => 'test_fact', "value" => 'test_value'}
}

agent_comm = Socket.tcp("localhost", 3001)
agent_comm.puts payload.to_msgpack
response_length = agent_comm.read(4).unpack("*i")[0]
require 'pp'
pp MessagePack.unpack(agent_comm.read(response_length))
