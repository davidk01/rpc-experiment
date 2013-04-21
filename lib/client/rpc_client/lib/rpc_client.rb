require "rpc_client/version"
require "rpc_client/client"

module RpcClient

  def self.make_client(opts)
    Client.new(opts)
  end

end
