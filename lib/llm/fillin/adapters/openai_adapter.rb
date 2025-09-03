# frozen_string_literal: true
require "openai"
require "json"

module LLM
  module Fillin
    class OpenAIAdapter
      def initialize(api_key:, model:, temperature: 0)
        @client = OpenAI::Client.new(access_token: api_key)
        @model = model
        @temperature = temperature
      end

      def step(system_prompt:, messages:, tools:, tool_results: [])
        resp = @client.chat(parameters: {
          model: @model,
          temperature: @temperature,
          tools: tools,
          tool_choice: "auto",
          messages: [{ role: "system", content: system_prompt }] +
                    messages +
                    tool_results
        })
        msg = resp.dig("choices", 0, "message")
        { tool_calls: msg["tool_calls"], content: msg["content"] }
      end

      def tool_result_message(tool_call_id:, name:, content:)
        { role: "tool", tool_call_id:, name:, content: content.to_json }
      end
    end
  end
end
