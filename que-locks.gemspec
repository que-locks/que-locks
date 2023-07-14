lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "que/locks/version"

Gem::Specification.new do |spec|
  spec.name = "que-locks"
  spec.version = Que::Locks::VERSION
  spec.authors = ["Harry Brundage"]
  spec.email = ["harry.brundage@gmail.com"]

  spec.summary = %q{Job locking for que jobs such that only one can be in the queue or executing at once.}
  spec.homepage = "https://github.com/que-locks/que-locks"
  spec.license = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|.github)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", '~> 2.0'
  spec.add_development_dependency "rake", "~> 13.0"

  spec.add_dependency "neatjson", '~> 0.9'
  spec.add_dependency "que", ['>= 1.0', '< 2.3']
  spec.add_dependency "xxhash", '~> 0.4'
end
