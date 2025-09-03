# frozen_string_literal: true
module LLM
  module Fillin
    Tool = Struct.new(:name, :version, :schema, :description, :handler, keyword_init: true)

    class Registry
      def initialize
        @tools = {}
      end

      def register!(name:, version:, schema:, description:, handler:)
        @tools[key_for(name, version)] = Tool.new(name:, version:, schema:, description:, handler:)
      end

      def tool(name, version: "v1")
        @tools.fetch(key_for(name, version))
      end

      def tools_for_llm
        @tools.values.map do |t|
          {
            type: "function",
            function: {
              name: "#{t.name}_#{t.version}",
              description: t.description,
              parameters: t.schema
            }
          }
        end
      end

      private

      def key_for(name, version) = "#{name}:#{version}"
    end
  end
end
