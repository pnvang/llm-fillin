# llm-fillin

**LLM-powered slot filling + tool orchestration for Ruby.**  
Turn natural language into structured, validated function calls.  
`llm-fillin` provides the glue between an LLM and your backend services.

---

## Install
```bash
bundle install
```

## Configure
Set your OpenAI API key:
```bash
export OPENAI_API_KEY=sk-...
```

## Run the demo
```bash
ruby examples/run_create_toy.rb
```

---

## Example Conversation

```text
AI: Got it! You want a red race car toy for $12. Could you please provide a name for this toy?
YOU: Supra
AI: You want a red race car toy named "Supra" for $12. Just to confirm, is the category of the toy "car"?
YOU: what other category are there?
AI: The toy categories available are plush, puzzle, doll, car, lego, and other. Would you like to proceed with the "car" category for the red race car toy named Supra?
YOU: make it lego
AI: You want a red Lego race car toy priced at $12. Just to confirm, is the toy name "Supra"?
YOU: yes
✅ Toy created: Supra (lego, red) - $12.0 | ID TOY-6A99ED
```

---

## How it works (Architecture)

When you interact with the assistant, several components collaborate:

### 1) Registry
The `Registry` is where tools (functions) are registered so the LLM can call them.  
Each tool has:
- `name` + `version`
- `schema` (JSON Schema that defines the inputs)
- `description` (human-readable prompt for the LLM)
- `handler` (Ruby lambda that executes the action)

**Example**
```ruby
registry.register!(
  name: "create_toy", version: "v1",
  schema: CREATE_TOY_V1,
  description: "Create a toy with name, category, price, and color.",
  handler: ->(args, ctx) { Toy.create!(args.merge(ctx)) }
)
```

### 2) Validators
All arguments are validated with [`json_schemer`](https://github.com/davishmcclurg/json_schemer) before a handler is called:
- Required fields must exist
- Types must match (string, integer, enum, etc.)
- No unexpected fields are allowed

This keeps your backend safe.

### 3) Idempotency
When creating resources, an idempotency key is generated with:
```ruby
"chat-<thread_id>-#{SecureRandom.hex(6)}"
```
This ensures the same request doesn’t create duplicates.

### 4) Orchestrator
The orchestrator coordinates everything:
- Supplies registered tools to the LLM
- Tracks conversation state and tool results
- Parses LLM output (text vs. function call)
- Validates arguments and calls the handler
- Stores tool results in memory

This is what lets the AI ask for missing fields naturally.

### 5) Adapters
Adapters handle communication with the LLM.  
Currently there’s an `OpenAIAdapter` that:
- Sends prompts, tools, and messages to OpenAI
- Parses responses (`tool_calls` or legacy `function_call`)
- Wraps tool results for reuse in the conversation

Other adapters could be added later for Anthropic, Mistral, or local LLMs.

### 6) StoreMemory
A simple in-memory store for tool results by thread.  
In production, this could be replaced by Redis or a database.

---

## End-to-End Flow
1. **User says**: `"I want a red race car toy for $12"`.
2. **LLM identifies intent**: `"create_toy_v1"`.
3. **LLM fills slots**: price = 1200, color = red. Missing: name, category.
4. **LLM asks user**: “What’s the name?” → “Supra”.
5. **LLM asks user**: “Is the category car?” → “make it lego”.
6. **Arguments validated** by `Validators`.
7. **Handler executes** with args + context + idempotency key.
8. **Result returned**: structured hash (toy ID, name, category, etc.).
9. **Assistant replies**: ✅ Toy created.

---

## Use in your app
- Define tools (schemas + handlers).
- Register them in the `Registry`.
- Wire the `Orchestrator` with an `Adapter` and a `Store`.
- Pass messages into `orchestrator.step`.
- Handle either assistant replies or tool execution results.

---

## License
MIT
