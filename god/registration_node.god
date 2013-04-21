God.watch do |w|
  w.name = "jruby-rpc-registration-node"
  w.dir = "/usr/share/jruby-rpc"
  start_command = [
    "java -jar rpc.jar registration_node",
    "--registration.port 3000",
    "--registration.timeout 10",
    "--query.port 3001",
    "--stale.heartbeat.time 5",
    "--reaper.sleep.time 240"
  ].join(" ")
  w.start = start_command
  w.log = "/var/log/jruby-rpc-registration-node.log"
  w.keepalive
end
