# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cronscription/version"

Gem::Specification.new do |s|
  s.name        = "cronscription"
  s.version     = Cronscription::VERSION
  s.authors     = ["Ben Feng"]
  s.email       = ["bfeng@enova.com"]
  s.homepage    = "https://git.cashnetusa.com/bfeng/cronscription"
  s.summary     = %q{Cron parsing}
  s.description = %q{Cron parsing}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
end
