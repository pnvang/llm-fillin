# frozen_string_literal: true
require "openai"
require "json"

module LLM
  module Fillin
    class OpenAIAdapter
      def initialize(api_key:, model:, temperature: 0)
        # Official OpenAI SDK (openai ~> 0.21.x)
        @client = OpenAI::Client.new(api_key: api_key)
        @model = model.to_sym         # e.g. :"gpt-4o-mini"
        @temperature = temperature
      end

      def step(system_prompt:, messages:, tools:, tool_results: [])
        response = @client.chat.completions.create(
          model: @model,                       # e.g. :"gpt-4o-mini" or "gpt-4o-mini"
          temperature: @temperature,
          messages: [{ role: "system", content: system_prompt }] + messages + tool_results,
          tools: tools,                        # [{ type: "function", function: {...} }, ...]
          tool_choice: "auto"
        )

        # In openai ~> 0.21, response is an object:
        # OpenAI::Models::Chat::ChatCompletion
        choice = response.choices.first
        msg    = choice.message               # OpenAI::Models::Chat::ChatCompletionMessage

        # Accessors vary by presence; guard with respond_to?
        tool_calls    = msg.respond_to?(:tool_calls)    ? msg.tool_calls    : nil
        function_call = msg.respond_to?(:function_call) ? msg.function_call : nil
        content       = msg.respond_to?(:content)       ? msg.content       : nil

        {
          tool_calls: tool_calls,             # Array or nil
          function_call: function_call,       # Hash-like or nil
          content: content                    # String or nil
        }
      end

      # Feed tool results back using role "tool" (tool calls) OR "function" (legacy).
      # We'll always emit the modern "tool" message; orchestrator can adapt.
      def tool_result_message(tool_call_id:, name:, content:)
        { role: "tool", tool_call_id: tool_call_id, name: name, content: content.to_json }
      end
    end
  end
end
