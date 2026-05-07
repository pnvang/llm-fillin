# frozen_string_literal: true

module LlmFillin
  Tool = Struct.new(:name, :version, :schema, :description, :handler, keyword_init: true)

  class Registry
    def initialize
      @tools = {}
      @workflows = {}
    end

    # 0.2 intake-workflow registration.
    def register(workflow)
      @workflows[workflow.name] = workflow
      workflow
    end
    alias register_workflow register

    def define(name, &block)
      register(Workflow.define(name, &block))
    end

    def fetch(name)
      @workflows.fetch(name.to_sym)
    end
    alias workflow fetch

    def [](name)
      @workflows[name.to_sym]
    end

    def workflows
      @workflows.values
    end

    # 0.1 tool registration, kept for existing apps.
    def register!(name:, version:, schema:, description:, handler:)
      @tools[key_for(name, version)] = Tool.new(
        name: name,
        version: version,
        schema: schema,
        description: description,
        handler: handler
      )
    end

    def tool(name, version: "v1")
      @tools.fetch(key_for(name, version))
    end

    def tools_for_llm
      @tools.values.map do |tool|
        {
          type: "function",
          function: {
            name: "#{tool.name}_#{tool.version}",
            description: tool.description,
            parameters: tool.schema
          }
        }
      end
    end

    private

    def key_for(name, version)
      "#{name}:#{version}"
    end
  end
end
