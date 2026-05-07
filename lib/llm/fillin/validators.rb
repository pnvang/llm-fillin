# frozen_string_literal: true

module LlmFillin
  class Validators
    def self.validate!(schema, args)
      require "json_schemer"
      schemer = JSONSchemer.schema(schema)
      errors = schemer.validate(args).to_a
      raise ArgumentError, "Schema validation failed: #{errors}" if errors.any?
    end
  end
end
