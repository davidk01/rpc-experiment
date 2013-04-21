rpc-experiment
==============

How hard is it to build a pluggable rpc framework? Turns out, not so hard if you use the right libraries, e.g.
celluloid, nio4r, etc.

Prerequisites
=============

You'll need jruby and warbler. I recommend installing jruby with rvm.

Creating JAR or DEB
===================

If you want to test it out to see how it works then all you have to do is clone the repo and run the rake
task that creates the jar file:
```
git clone https://github.com/davidk01/rpc-experiment.git
rake rpc.jar
```

Then just run `java -jar rpc.jar` to get a help menu and proceed with either starting an agent node or
a registration node. To test things locally take a look at `god` subdirectory for some standard command
line options. You can also get all the command line options by running `java -jar rpc.jar agent_node --help`
for the agent node options and similarly `java -jar rpc.jar registration_node --help` for the registration
node options.

To create a debian package you'll need `fpm` and you'll also need a ruby interpreter other than jruby. Once you
got those just run `rake make_debian[1.0]` to build a debian package. I'm using rake's tasks with parameters and
the task just takes a version parameter.

Agent Interaction
=================

Once you have an agent node and a registration node up and running the next thing to do is to interact with them
from ruby. You'll need to make and install the client gem but that's pretty easy:
```
cd lib/client/rpc_client
rake install
```

Now just open up an `irb` prompt and require the client library: `require 'rpc_client'`. Take a look at `test.rb`
for how to use the client.
