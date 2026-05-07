# frozen_string_literal: true
require "digest"
require "json"
require "securerandom"

module LlmFillin
  module Idempotency
    class MemoryStore
      def initialize
        @executions = {}
      end

      def fetch(key)
        @executions[key]
      end

      def store(key, execution)
        @executions[key] = execution
      end

      def executed?(key)
        @executions.key?(key)
      end
    end

    def self.generate(thread_id: nil, workflow: nil, context: {}, values: {})
      return "chat-#{thread_id}-#{SecureRandom.hex(6)}" unless workflow

      seed = {
        workflow: workflow.name.to_s,
        tenant_id: context[:tenant_id] || context["tenant_id"],
        actor_id: context[:actor_id] || context["actor_id"],
        thread_id: context[:thread_id] || context["thread_id"],
        values: canonicalize(values)
      }

      "intake-#{Digest::SHA256.hexdigest(JSON.generate(seed))[0, 24]}"
    end

    def self.canonicalize(value)
      case value
      when Hash
        value.keys.map(&:to_s).sort.each_with_object({}) do |key, out|
          source_key = value.key?(key.to_sym) ? key.to_sym : key
          out[key] = canonicalize(value[source_key])
        end
      when Array
        value.map { |item| canonicalize(item) }
      else
        value
      end
    end
    private_class_method :canonicalize
  end
end
