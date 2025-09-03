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

        # --- New-style tools (preferred) ---
        if (calls = res[:tool_calls]).is_a?(Array) && calls.any?
          call = calls.first
          # In openai 0.21.x these are typed objects:
          # call => OpenAI::Models::Chat::ChatCompletionMessageFunctionToolCall
          # call.function => OpenAI::Models::Chat::ChatCompletionMessageFunctionCall

          fn   = call.respond_to?(:function) ? call.function : nil
          name = fn&.respond_to?(:name) ? fn.name : nil                       # e.g., "create_toy_v1"
          args_json = fn&.respond_to?(:arguments) ? fn.arguments.to_s : "{}"
          args = args_json.empty? ? {} : JSON.parse(args_json)

          tool_name, version = (name || "").split(/_v/i)
          version ||= "v1"

          tool = @registry.tool(tool_name, version: "v1")
          Validators.validate!(tool.schema, args)

          ctx = { tenant_id: tenant_id, actor_id: actor_id, thread_id: thread_id }
          result = tool.handler.call(args, ctx)

          tool_msg = @adapter.tool_result_message(
            tool_call_id: call.respond_to?(:id) ? call.id : nil,
            name: "#{tool_name}_v1",
            content: result
          )
          @store.push_tool_message(thread_id, tool_msg)

          return { type: :tool_ran, tool_name: tool_name, result: result }
        end

        # --- Legacy single function_call (fallback) ---
        if (fc = res[:function_call])
          name_with_version = fc["name"]
          args_json = fc["arguments"].to_s
          args = args_json.empty? ? {} : JSON.parse(args_json)

          tool_name, version = name_with_version.split(/_v/i)
          version ||= "v1"

          tool = @registry.tool(tool_name, version: "v1")
          Validators.validate!(tool.schema, args)

          ctx = { tenant_id: tenant_id, actor_id: actor_id, thread_id: thread_id }
          result = tool.handler.call(args, ctx)

          # Legacy role is "function"; we already store tool messages in memory,
          # not required for a single-step demo, but safe to omit or adapt if needed.

          return { type: :tool_ran, tool_name: tool_name, result: result }
        end

        # No tool call -> just assistant text (likely a clarifying question)
        { type: :assistant, text: res[:content].to_s }
      end
    end
  end
end
