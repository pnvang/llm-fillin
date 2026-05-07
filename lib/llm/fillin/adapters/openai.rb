# frozen_string_literal: true

require "json"

module LlmFillin
  module Adapters
    class OpenAI < Base
      EXTRACTION_PROMPT = <<~PROMPT
        You extract values for an AI intake form. Return JSON only.
        The response must be an object with a "slots" object containing only known slot names.
        Omit slots that are not present or confidently implied by the user's message.
      PROMPT

      attr_reader :model, :temperature

      def initialize(api_key: nil, model: "gpt-4.1-mini", temperature: 0, client: nil)
        @client = client || build_client(api_key)
        @model = model
        @temperature = temperature
      end

      def extract(workflow:, message:, slots:, context:)
        response = @client.chat.completions.create(
          model: model,
          temperature: temperature,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: EXTRACTION_PROMPT },
            { role: "user", content: extraction_payload(workflow, message, slots, context) }
          ]
        )

        parse_slots(content_from(response), workflow)
      end

      # Backwards-compatible tool-call API used by llm-fillin 0.1.
      def step(system_prompt:, messages:, tools:, tool_results: [])
        response = @client.chat.completions.create(
          model: model,
          temperature: temperature,
          messages: [{ role: "system", content: system_prompt }] + messages + tool_results,
          tools: tools,
          tool_choice: "auto"
        )

        message = message_from(response)

        {
          tool_calls: object_value(message, :tool_calls),
          function_call: object_value(message, :function_call),
          content: object_value(message, :content)
        }
      end

      def tool_result_message(tool_call_id:, name:, content:)
        { role: "tool", tool_call_id: tool_call_id, name: name, content: content.to_json }
      end

      private

      def build_client(api_key)
        require "openai"
        ::OpenAI::Client.new(api_key: api_key)
      rescue LoadError
        raise LoadError, "The OpenAI adapter is optional. Add `gem \"openai\"` to your app to use it."
      end

      def extraction_payload(workflow, message, slots, context)
        JSON.pretty_generate(
          workflow: workflow.name,
          description: workflow.description,
          schema: workflow.to_json_schema,
          already_filled_slots: slots,
          context: context,
          user_message: message
        )
      end

      def parse_slots(content, workflow)
        parsed = content.to_s.strip.empty? ? {} : JSON.parse(content)
        raw_slots = parsed["slots"].is_a?(Hash) ? parsed["slots"] : parsed

        raw_slots.each_with_object({}) do |(key, value), out|
          name = key.to_sym
          out[name] = value if workflow.slots[name]
        end
      rescue JSON::ParserError
        {}
      end

      def content_from(response)
        object_value(message_from(response), :content).to_s
      end

      def message_from(response)
        choice = object_value(response, :choices)&.first
        object_value(choice, :message)
      end

      def object_value(object, key)
        return nil unless object
        return object.public_send(key) if object.respond_to?(key)
        return object[key] if object.respond_to?(:key?) && object.key?(key)
        return object[key.to_s] if object.respond_to?(:key?) && object.key?(key.to_s)

        nil
      end
    end
  end

  class OpenAIAdapter < Adapters::OpenAI
  end
end
