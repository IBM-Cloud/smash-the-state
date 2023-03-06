$LOAD_PATH.push File.expand_path("../lib", __dir__)
require File.expand_path('lib/smash_the_state/version.rb', __dir__)

Gem::Specification.new do |s|
  s.name        = "smash_the_state"
  s.version     = SmashTheState::VERSION
  s.authors     = ["Dan Connor"]
  s.email       = ["dan@danconnor.com"]
  s.homepage    = "https://github.com/ibm-cloud/smash-the-state"
  s.summary     = "A useful utility for transforming state that provides step " \
                  "sequencing, middleware, and validation."
  s.description = ""
  s.required_ruby_version = "3.2"
  s.license = "Apache-2.0"

  s.files = Dir["{lib}/**/*",
                "spec/unit/**/*",
                "Rakefile",
                "README.md"]

  s.add_dependency "active_model_attributes", "~> 1.2.0"
  s.add_dependency "activesupport", ">= 6.0.0"
end
