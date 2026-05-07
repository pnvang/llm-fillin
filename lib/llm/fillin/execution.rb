# frozen_string_literal: true

module LlmFillin
  class Execution
    attr_reader :idempotency_key, :result, :error, :status

    def self.completed(idempotency_key:, result:)
      new(idempotency_key: idempotency_key, result: result, status: :completed)
    end

    def self.duplicate(idempotency_key:, result:)
      new(idempotency_key: idempotency_key, result: result, status: :duplicate)
    end

    def self.failed(idempotency_key:, error:)
      new(idempotency_key: idempotency_key, error: error, status: :failed)
    end

    def initialize(idempotency_key:, result: nil, error: nil, status:)
      @idempotency_key = idempotency_key
      @result = result
      @error = error
      @status = status
    end

    def completed?
      status == :completed || status == :duplicate
    end

    def duplicate?
      status == :duplicate
    end

    def failed?
      status == :failed
    end
  end
end
