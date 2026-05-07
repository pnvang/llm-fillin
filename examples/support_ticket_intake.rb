# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "llm/fillin"

workflow = LlmFillin::Workflow.define(:support_ticket) do
  description "Collect support details before opening a ticket"

  slot :email, type: :string, required: true, format: :email
  slot :summary, type: :string, required: true
  slot :priority, type: :string, enum: %w[low normal high urgent], required: false
  slot :account_id, type: :string, required: false

  confirm_before_submit true

  handler do |values, context|
    {
      ticket_id: "ticket_001",
      created_by: context[:actor_id],
      values: values
    }
  end
end

adapter = LlmFillin::Adapters::Fake.new(
  responses: [
    { email: "pat@example.com", summary: "Cannot export invoices", priority: "high" }
  ]
)

intake = LlmFillin::Intake.new(workflow, adapter: adapter)
pending = intake.step("I cannot export invoices. Email me at pat@example.com. This is high priority.")
executed = intake.step("confirm", state: pending.state, context: { actor_id: "user_1", thread_id: "support-thread" })

puts pending.to_h
puts executed.to_h
