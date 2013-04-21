require 'socket'
require 'pp'
require 'json'
require_relative './lib/client/client'

payload2 = {
  :plugin => 'host.discovery',
  :action => 'facts',
  :arguments => {}
}

c = Client.new(:registration_server => "localhost", :query_port => 3001)
puts "Client instantiated."
puts "Testing fact filtering."
res = c.agents[0].act("host.discovery", "fact_filter", {"fact" => "test_fact", "value" => "test_value"})
pp res
puts "Testing fact loading."
res = c.agents[0].act('host.discovery', 'facts', {})
pp res
