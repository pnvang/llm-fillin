# frozen_string_literal: true
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "llm/fillin"
require "llm/fillin/toys"

registry = LLM::Fillin::Registry.new
LLM::Fillin.register_toy_tools!(registry)

adapter = LLM::Fillin::OpenAIAdapter.new(
  api_key: ENV.fetch("OPENAI_API_KEY"),
  model: "gpt-4.1-mini",
  temperature: 0
)
store = LLM::Fillin::StoreMemory.new
orch  = LLM::Fillin::Orchestrator.new(adapter: adapter, registry: registry, store: store)

thread_id = "demo-123"
tenant_id = "org_123"
actor_id  = "user_42"

messages = [
  { role: "user", content: "I want a red race car toy for $12" }
]

loop do
  outcome = orch.step(thread_id: thread_id, tenant_id: tenant_id, actor_id: actor_id, messages: messages)

  case outcome[:type]
  when :assistant
    puts "AI: #{outcome[:text]}"
    print "YOU: "
    input = STDIN.gets&.strip
    break unless input
    messages << { role: "user", content: input }
  when :tool_ran
    toy = outcome[:result]
    puts "✅ Toy created: #{toy[:name]} (#{toy[:category]}, #{toy[:color]}) - $#{toy[:price_minor].to_i/100.0} | ID #{toy[:id]}"
    break
  end
end
