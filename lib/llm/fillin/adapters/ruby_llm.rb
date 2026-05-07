# frozen_string_literal: true

require "json"

module LlmFillin
  module Adapters
    class RubyLLM < Base
      def initialize(chat: nil, model: nil)
        @chat = chat || build_chat(model)
      end

      def extract(workflow:, message:, slots:, context:)
        response = @chat.ask(prompt_for(workflow, message, slots, context))
        parse_slots(response_content(response), workflow)
      end

      private

      def build_chat(model)
        require "ruby_llm"
        model ? ::RubyLLM.chat(model: model) : ::RubyLLM.chat
      rescue LoadError
        raise LoadError, "The RubyLLM adapter is optional. Add `gem \"ruby_llm\"` to your app to use it."
      end

      def prompt_for(workflow, message, slots, context)
        <<~PROMPT
          Extract values for this AI intake form and return JSON only.
          Return an object with a "slots" object containing only known slot names.

          #{JSON.pretty_generate(
            workflow: workflow.name,
            description: workflow.description,
            schema: workflow.to_json_schema,
            already_filled_slots: slots,
            context: context,
            user_message: message
          )}
        PROMPT
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

      def response_content(response)
        return response.content if response.respond_to?(:content)
        return response.text if response.respond_to?(:text)

        response.to_s
      end
    end
  end
end
