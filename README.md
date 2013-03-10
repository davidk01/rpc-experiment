rpc-experiment
==============

How hard is it to build a pluggable rpc framework? The pluggable component is super easy. This is ruby after all.
The network/socket component is what contains all the complexity. nio4r and celluloid simplify some things but not 
enough. Ff the goal is to make the registration server as robust and resource efficient as possible then there
is no way around hand-crafting some state machines and using `readpartial`.
