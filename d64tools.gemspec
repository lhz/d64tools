# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'd64/version'

Gem::Specification.new do |spec|
  spec.name          = "d64tools"
  spec.version       = D64::VERSION
  spec.authors       = ["Lars Haugseth"]
  spec.email         = ["github@larshaugseth.com"]

  spec.summary       = %q{D64 floppy image tools}
  spec.description   = %q{Tools to perform various operations on D64 floppy images.}
  spec.homepage      = "http://github.com/lhz/d64tools"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "pry", "~> 0.10"
end
