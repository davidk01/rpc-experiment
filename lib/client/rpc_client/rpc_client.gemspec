# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rpc_client/version'

Gem::Specification.new do |spec|
  spec.name          = "rpc_client"
  spec.version       = RpcClient::VERSION
  spec.authors       = ["david karapetyan"]
  spec.email         = ["dkarapetyan@gmail.com"]
  spec.description   = %q{A simple client for talking to registration server.}
  spec.summary       = %q{A simple client that uses the JSON rpc to talk to registration and agent nodes.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
