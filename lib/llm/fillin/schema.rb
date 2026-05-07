# frozen_string_literal: true

module LlmFillin
  class Schema
    Validation = Struct.new(:values, :missing_slots, :invalid_slots, keyword_init: true) do
      def valid?
        missing_slots.empty? && invalid_slots.empty?
      end
    end

    attr_reader :slots

    def initialize(slots)
      @slots = slots
    end

    def validate(values)
      coerced = slots.coerce(values)
      invalid = {}

      slots.each do |slot|
        value = coerced[slot.name]
        errors = slot.validation_errors(value)
        invalid[slot.name] = errors if errors.any? && !slot.blank?(value)
      end

      Validation.new(
        values: coerced,
        missing_slots: slots.missing_required(coerced),
        invalid_slots: invalid
      )
    end

    def to_json_schema
      slots.to_json_schema
    end
  end
end
