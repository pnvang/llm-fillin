# frozen_string_literal: true

require_relative "fillin/version"

module LlmFillin
  class << self
    def registry
      @registry ||= Registry.new
    end

    def define(name, &block)
      registry.define(name, &block)
    end

    def workflow(name)
      registry.fetch(name)
    end

    def intake(name, adapter:, idempotency: nil)
      selected_workflow = name.is_a?(Workflow) ? name : workflow(name)
      Intake.new(selected_workflow, adapter: adapter, idempotency: idempotency)
    end
  end
end

module LLM
  Fillin = ::LlmFillin unless const_defined?(:Fillin)
end

require_relative "fillin/slot"
require_relative "fillin/slot_set"
require_relative "fillin/schema"
require_relative "fillin/workflow"
require_relative "fillin/registry"
require_relative "fillin/result"
require_relative "fillin/execution"
require_relative "fillin/idempotency"
require_relative "fillin/intake"
require_relative "fillin/orchestrator"
require_relative "fillin/validators"
require_relative "fillin/adapters/base"
require_relative "fillin/adapters/fake"
require_relative "fillin/adapters/openai"
require_relative "fillin/adapters/ruby_llm"
require_relative "fillin/adapters/openai_adapter"
require_relative "fillin/adapters/store_memory"
