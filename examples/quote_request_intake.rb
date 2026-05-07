# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "llm/fillin"

workflow = LlmFillin::Workflow.define(:quote_request) do
  description "Collect enough detail to prepare a quote"

  slot :name, type: :string, required: true
  slot :email, type: :string, required: true, format: :email
  slot :project_type, type: :string, required: true
  slot :budget, type: :integer, required: false
  slot :timeline, type: :string, required: false
  slot :notes, type: :string, required: false

  confirm_before_submit true

  handler do |values, context|
    {
      quote_request_id: "quote_001",
      values: values,
      idempotency_key: context.fetch(:idempotency_key)
    }
  end
end

adapter = LlmFillin::Adapters::Fake.new(
  responses: [
    {
      name: "Jordan Lee",
      email: "jordan@example.com",
      project_type: "Website refresh",
      budget: "12000",
      timeline: "next quarter"
    }
  ]
)

orchestrator = LlmFillin::Orchestrator.new(workflow: workflow, adapter: adapter)
pending = orchestrator.step("Jordan wants a website refresh next quarter around $12k. jordan@example.com")
executed = orchestrator.step("yes", state: pending.state)

puts pending.to_h
puts executed.to_h
