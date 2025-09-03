# frozen_string_literal: true
require "json_schemer"

module LLM
  module Fillin
    class Validators
      def self.validate!(schema, args)
        schemer = JSONSchemer.schema(schema)
        errors = schemer.validate(args).to_a
        raise ArgumentError, "Schema validation failed: #{errors}" if errors.any?
      end
    end
  end
end
