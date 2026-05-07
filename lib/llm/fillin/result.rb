# frozen_string_literal: true

module LlmFillin
  class Result
    attr_reader :status, :message, :slots, :missing_slots, :invalid_slots,
                :confirmed, :execution, :idempotency_key, :state, :workflow

    def initialize(status:, message:, workflow:, slots:, missing_slots: [], invalid_slots: {},
                   confirmed: false, execution: nil, idempotency_key: nil, state: nil)
      @status = status
      @message = message
      @workflow = workflow
      @slots = slots
      @missing_slots = missing_slots
      @invalid_slots = invalid_slots
      @confirmed = confirmed
      @execution = execution
      @idempotency_key = idempotency_key
      @state = state || build_state
    end

    def ready_to_confirm?
      status == :needs_confirmation
    end

    def ready_to_execute?
      valid_required_slots? && (!workflow.confirm_before_submit? || confirmed?)
    end

    def confirmed?
      !!confirmed
    end

    def executed?
      status == :executed && execution&.completed?
    end

    def execution_result
      execution&.result
    end

    def to_h
      {
        status: status,
        message: message,
        slots: slots,
        missing_slots: missing_slots,
        invalid_slots: invalid_slots,
        confirmed: confirmed?,
        ready_to_confirm: ready_to_confirm?,
        ready_to_execute: ready_to_execute?,
        executed: executed?,
        execution_result: execution_result,
        idempotency_key: idempotency_key
      }
    end

    private

    def valid_required_slots?
      missing_slots.empty? && invalid_slots.empty?
    end

    def build_state
      {
        "workflow" => workflow.name.to_s,
        "slots" => stringify_keys(slots),
        "confirmed" => confirmed?,
        "idempotency_key" => idempotency_key,
        "executed" => executed?,
        "execution_result" => execution_result
      }
    end

    def stringify_keys(hash)
      hash.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
    end
  end
end
