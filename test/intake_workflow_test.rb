# frozen_string_literal: true

require_relative "test_helper"

class IntakeWorkflowTest < Minitest::Test
  def setup
    LlmFillin.instance_variable_set(:@registry, LlmFillin::Registry.new)
  end

  def test_defines_an_intake_workflow
    workflow = LlmFillin.define(:support_ticket) do
      description "Collect support details before opening a ticket"

      slot :email, type: :string, required: true, format: :email
      slot :summary, type: :string, required: true
      slot :priority, type: :string, enum: %w[low normal high], required: false

      handler { |values, _context| values }
    end

    assert_same workflow, LlmFillin.workflow(:support_ticket)
    assert_equal "Collect support details before opening a ticket", workflow.description
    assert_equal %i[email summary priority], workflow.slots.names
    assert_equal %w[email summary], workflow.to_json_schema.fetch("required")
  end

  def test_extracts_slots_with_fake_adapter_and_asks_for_missing_required_slot
    workflow = booking_workflow
    adapter = LlmFillin::Adapters::Fake.new(
      responses: [
        {
          name: "Mina",
          event_date: "2026-06-20",
          start_time: "6:00 PM",
          end_time: "10:00 PM",
          location: "Community Hall"
        }
      ]
    )

    result = LlmFillin::Orchestrator.new(workflow: workflow, adapter: adapter)
                                 .step("I need the hall on June 20 from 6 to 10. My name is Mina.")

    assert_equal :needs_clarification, result.status
    assert_equal "What is the email?", result.message
    assert_equal "Mina", result.slots[:name]
    assert_equal [:email], result.missing_slots
    refute result.ready_to_confirm?
    refute result.executed?
  end

  def test_validates_invalid_slot_values
    workflow = booking_workflow
    adapter = LlmFillin::Adapters::Fake.new(
      responses: [
        complete_booking_slots.merge(email: "not-an-email")
      ]
    )

    result = LlmFillin::Orchestrator.new(workflow: workflow, adapter: adapter)
                                 .step("Here are the booking details.")

    assert_equal :invalid, result.status
    assert_equal({ email: ["must be a valid email"] }, result.invalid_slots)
    assert_equal "Please provide a valid email.", result.message
    refute result.ready_to_execute?
  end

  def test_requires_confirmation_before_execution
    calls = []
    workflow = booking_workflow(calls: calls)
    adapter = LlmFillin::Adapters::Fake.new(responses: [complete_booking_slots])

    result = LlmFillin::Orchestrator.new(workflow: workflow, adapter: adapter)
                                 .step("Book this event.", context: conversation_context)

    assert_equal :needs_confirmation, result.status
    assert_match(/Please confirm:/, result.message)
    assert result.ready_to_confirm?
    refute result.ready_to_execute?
    assert_empty calls
    refute_nil result.idempotency_key
  end

  def test_executes_handler_after_confirmation
    calls = []
    workflow = booking_workflow(calls: calls)
    adapter = LlmFillin::Adapters::Fake.new(responses: [complete_booking_slots])
    orchestrator = LlmFillin::Orchestrator.new(workflow: workflow, adapter: adapter)

    pending = orchestrator.step("Book this event.", context: conversation_context)
    executed = orchestrator.step("yes", state: pending.state, context: conversation_context)

    assert_equal :executed, executed.status
    assert executed.executed?
    assert executed.ready_to_execute?
    assert_equal 1, calls.length
    assert_equal "lead_1", executed.execution_result.fetch(:id)
    assert_equal pending.idempotency_key, executed.idempotency_key
    assert_equal executed.idempotency_key, calls.first.fetch(:idempotency_key)
  end

  def test_prevents_duplicate_handler_execution_with_idempotency_key
    calls = []
    workflow = booking_workflow(calls: calls)
    adapter = LlmFillin::Adapters::Fake.new(responses: [complete_booking_slots])
    orchestrator = LlmFillin::Orchestrator.new(workflow: workflow, adapter: adapter)

    pending = orchestrator.step("Book this event.", context: conversation_context)
    first = orchestrator.step("yes", state: pending.state, context: conversation_context)
    duplicate = orchestrator.step("yes", state: first.state, context: conversation_context)

    assert_equal :executed, duplicate.status
    assert duplicate.executed?
    assert duplicate.execution.duplicate?
    assert_equal 1, calls.length
    assert_equal first.execution_result, duplicate.execution_result
    assert_equal first.idempotency_key, duplicate.idempotency_key
  end

  private

  def booking_workflow(calls: [])
    LlmFillin::Workflow.define(:booking_lead) do
      description "Collect event details before creating a booking lead"

      slot :name, type: :string, required: true
      slot :email, type: :string, required: true, format: :email
      slot :event_date, type: :date, required: true
      slot :start_time, type: :string, required: true
      slot :end_time, type: :string, required: true
      slot :location, type: :string, required: true
      slot :guest_count, type: :integer, required: false
      slot :package, type: :string, enum: ["Gold", "Platinum", "Emerald"], required: false
      slot :tax_exempt, type: :boolean, required: false

      confirm_before_submit true

      handler do |values, context|
        calls << {
          values: values,
          idempotency_key: context.fetch(:idempotency_key),
          workflow_name: context.fetch(:workflow_name)
        }

        { id: "lead_#{calls.length}", accepted: true, values: values }
      end
    end
  end

  def complete_booking_slots
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
  end

  def conversation_context
    { tenant_id: "tenant_1", actor_id: "user_1", thread_id: "thread_1" }
  end
end
