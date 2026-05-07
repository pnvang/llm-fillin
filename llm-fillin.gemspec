# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name        = "llm-fillin"
  s.version     = "0.2.0"
  s.summary     = "Rails-native AI intake forms and slot-filling workflows for Ruby."
  s.description = "Turn messy user messages into structured Ruby actions with AI intake forms, slot-filling workflows, validation, confirmation, and idempotent handler execution."
  s.authors     = ["Phia Vang"]
  s.email       = ["pnvang@gmail.com"]
  s.homepage    = "https://github.com/pnvang/llm-fillin"
  s.license     = "MIT"

  s.files = Dir["lib/**/*", "README.md", "CHANGELOG.md", "LICENSE", "bin/*", "examples/*"]
  s.bindir = "bin"
  s.executables = ["console"]
  s.required_ruby_version = ">= 3.1"

  s.add_dependency "json_schemer", "~> 2.4"

  s.add_development_dependency "minitest", "~> 5.25"
end
