rpc-experiment
==============

How hard is it to build a pluggable rpc framework? The pluggable component is super easy. This is ruby after all.
The network/socket component is what contains all the complexity. 

Some issues I've run into so far. A robust/scalable heartbeat mechanism is a lot more tricky than it appears.
Doing the simplest possible thing where heartbeat == registration and the clients register every so often is simple
but expensive in terms of resources. Keeping the connection open is better but now if we want to do it right then
we need some kind of select loop which introduces asynchronous callbacks. I've decided to use nio4r because it is
pretty simple and does the right thing behind the scenes so we'll see how that goes.
