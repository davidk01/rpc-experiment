require 'socket'
require 'pp'
require 'logger'
require 'msgpack'
require_relative './client/client'
$logger = Logger.new(STDOUT, 'daily'); Thread.abort_on_exception = true
payload = {
  :plugin => 'host.discovery',
  :action => 'fact_filter',
  :arguments => {"fact" => 'test_fact', "value" => 'test_value'}
}

c = Client.new(:registration_server => "localhost", :query_port => 3001)
res = c.agents[0].act("host.discovery", "fact_filter", {"fact" => "test_fact", "value" => "test_value"})
pp res
