# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "llm/fillin"

workflow = LlmFillin::Workflow.define(:booking_lead) do
  description "Collect event details before creating a booking lead"

  slot :name, type: :string, required: true
  slot :email, type: :string, required: true, format: :email
  slot :event_date, type: :date, required: true
  slot :start_time, type: :string, required: true
  slot :end_time, type: :string, required: true
  slot :location, type: :string, required: true
  slot :guest_count, type: :integer, required: false
  slot :package, type: :string, enum: ["Gold", "Platinum", "Emerald"], required: false
  slot :backdrop, type: :string, required: false
  slot :tax_exempt, type: :boolean, required: false

  confirm_before_submit true

  handler do |values, context|
    {
      id: "lead_001",
      values: values,
      idempotency_key: context.fetch(:idempotency_key)
    }
  end
end

adapter = LlmFillin::Adapters::Fake.new(
  responses: [
    {
      name: "Mina Park",
      email: "mina@example.com",
      event_date: "2026-06-20",
      start_time: "6:00 PM",
      end_time: "10:00 PM",
      location: "Community Hall",
      guest_count: "75",
      package: "Gold",
      tax_exempt: "false"
    }
  ]
)

orchestrator = LlmFillin::Orchestrator.new(workflow: workflow, adapter: adapter)
context = { tenant_id: "demo", actor_id: "user_1", thread_id: "booking-thread" }

pending = orchestrator.step("I need a Gold package for 75 guests on June 20.", context: context)
puts pending.to_h

executed = orchestrator.step("yes", state: pending.state, context: context)
puts executed.to_h
