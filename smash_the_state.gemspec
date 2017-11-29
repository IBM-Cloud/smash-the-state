$LOAD_PATH.push File.expand_path("../lib", __FILE__)

require "smash_the_state/version"

Gem::Specification.new do |s|
  s.name        = "smash_the_state"
  s.version     = SmashTheState::VERSION
  s.authors     = ["Dan Connor"]
  s.email       = ["dan@compose.io"]
  s.homepage    = "https://github.ibm.com/compose/smash_the_state"
  s.summary     = "A useful utility for transforming state that provides step " \
                  "sequencing, middleware, and validation."
  s.description = ""
  s.license     = "MIT"

  s.files = Dir["{lib}/**/*",
                "spec/unit/**/*",
                "Rakefile",
                "README.md"]

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if s.respond_to?(:metadata)
    s.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  s.add_dependency "active_model_attributes", "~> 1.2.0"
end
