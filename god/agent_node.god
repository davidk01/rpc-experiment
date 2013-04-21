God.watch do |w|
  w.name = "jruby-rpc-agent-node"
  w.dir = "/usr/share/jruby-rpc"
  start_command = [
    "java -jar rpc.jar agent_node",
    "--registration.server localhost",
    "--registration.server.port 3000",
    "--agent.dispatch.port 3002",
    "--registration.wait.period 10",
    "--heartbeat.wait.period 20"
  ].join(" ")
  w.start = start_command
  w.log = "/var/log/jruby-rpc-agent-node.log"
  w.keepalive
end
