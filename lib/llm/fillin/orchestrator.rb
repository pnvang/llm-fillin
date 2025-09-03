# frozen_string_literal: true
require "json"

module LLM
  module Fillin
    class Orchestrator
      POLICY = <<~SYS
        You are a task-oriented assistant. Identify intent, extract entities,
        ask for missing required fields one at a time, and call exactly one function when ready.
        Keep replies concise and friendly.
      SYS

      def initialize(adapter:, registry:, store:)
        @adapter, @registry, @store = adapter, registry, store
      end

      # messages: [{role:"user", content:"..."}]
      def step(thread_id:, tenant_id:, actor_id:, messages:)
        prior_tool_msgs = @store.fetch_tool_messages(thread_id)
        res = @adapter.step(
          system_prompt: POLICY,
          messages: messages,
          tools: @registry.tools_for_llm,
          tool_results: prior_tool_msgs
        )

        if (calls = res[:tool_calls]).is_a?(Array) && calls.any?
          call = calls.first
          name, version = call.dig("function", "name").split(/_v/i)
          args = JSON.parse(call.dig("function", "arguments") || "{}")

          tool = @registry.tool(name, version: "v1")
          Validators.validate!(tool.schema, args)

          ctx = { tenant_id:, actor_id:, thread_id: }
          result = tool.handler.call(args, ctx)

          tool_msg = @adapter.tool_result_message(
            tool_call_id: call["id"],
            name: "#{name}_v1",
            content: result
          )
          @store.push_tool_message(thread_id, tool_msg)

          { type: :tool_ran, tool_name: name, result: result }
        else
          { type: :assistant, text: res[:content].to_s }
        end
      end
    end
  end
end
