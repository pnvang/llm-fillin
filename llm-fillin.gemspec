# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name        = "llm-fillin"
  s.version     = "0.1.1"
  s.summary     = "LLM-powered slot filling and tool orchestration for Ruby."
  s.description = "Register JSON-schema tools and let an LLM handle intent, slot-filling, and tool calls safely."
  s.authors     = ["Phia Vang"]
  s.email       = ["pnvang@gmail.com"]
  s.homepage    = "https://github.com/pnvang/llm-fillin"
  s.license     = "MIT"

  s.files = Dir["lib/**/*", "README.md", "LICENSE", "bin/*", "examples/*"]
  s.bindir = "bin"
  s.executables = ["console"]
  s.required_ruby_version = ">= 3.1"

  s.add_dependency "openai", "~> 0.21"
  s.add_dependency "json_schemer", "~> 2.3"
end
