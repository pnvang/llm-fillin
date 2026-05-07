# frozen_string_literal: true

module LlmFillin
  class Intake
    attr_reader :workflow, :orchestrator

    def initialize(workflow, adapter:, idempotency: nil)
      @workflow = workflow.is_a?(Workflow) ? workflow : LlmFillin.workflow(workflow)
      @orchestrator = Orchestrator.new(workflow: @workflow, adapter: adapter, idempotency: idempotency)
    end

    def step(message, state: nil, context: {}, idempotency_key: nil, confirm: nil)
      orchestrator.step(message, state: state, context: context, idempotency_key: idempotency_key, confirm: confirm)
    end
  end
end
