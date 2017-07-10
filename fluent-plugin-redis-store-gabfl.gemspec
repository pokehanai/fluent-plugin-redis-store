# -*- encoding: utf-8 -*-
Gem::Specification.new do |gem|
    gem.name        = "fluent-plugin-redis-store-gabfl"
    gem.email       = "pypi@gab.lc"
    gem.version     = "0.1.2"
    gem.authors     = ["moaikids", "HANAI Tohru aka pokehanai", "Gabriel Bordeaux"]
    gem.licenses    = ["Apache License Version 2.0"]
    gem.summary     = %q{Redis(zset/set/list/string/publish) output plugin for Fluentd}
    gem.description = %q{Redis(zset/set/list/string/publish) output plugin for Fluentd...}
    gem.homepage    = "https://github.com/gabfl/fluent-plugin-redis-store"

    gem.files         = `git ls-files`.split($\)
    gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
    gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
    gem.require_paths = ["lib"]

    gem.add_development_dependency "rake"
    gem.add_development_dependency "test-unit"
    gem.add_runtime_dependency "fluentd"
    gem.add_runtime_dependency "redis"
end
