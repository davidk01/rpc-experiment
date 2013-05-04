#!/usr/bin/env ruby
if `god status` =~ /The server is not available/
  `god -c /usr/share/jruby-rpc/god/agent_node.god`
else
  `god terminate`
  `god -c /usr/share/jruby-rpc/god/agent_node.god`
end
