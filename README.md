
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

When you talk to the assistant, several components collaborate:

### 1) Registry
The `Registry` is where you **register tools** (functions) that the LLM can call.  
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

This makes the tool visible to the LLM. The schema ensures the AI knows **what fields to collect**.

### 2) Validators
Before calling your handler, the orchestrator runs all arguments through `Validators`.  
It uses [`json_schemer`](https://github.com/davishmcclurg/json_schemer) to enforce:
- Required fields exist
- Field types are correct (string, integer, enum values)
- No extra fields sneak in

This prevents the LLM from passing junk or unsafe data into your backend.

### 3) Idempotency
For creates (e.g., invoices, toys, registrations), avoid duplicates if the same request runs twice.  

`Idempotency.generate(thread_id:)` creates a unique key:
```ruby
"chat-<thread_id>-#{SecureRandom.hex(6)}"
```
Handlers include this key when persisting. If the same request repeats, your backend can safely return the original object instead of creating a duplicate.

### 4) Orchestrator
The `Orchestrator` is the central loop:
- Supplies your tools (from `Registry`) to the LLM
- Tracks conversation state (including tool results)
- Receives LLM output
- Decides: clarifying question vs. tool call
- Validates args and runs the `handler`
- Stores tool results back in the memory store

This is what lets the AI ask:  
> “I need the category — plush, puzzle, doll, car, lego, or other?”

### 5) Adapters
Adapters wrap the actual LLM API. We ship an `OpenAIAdapter`, which:
- Sends prompts, tools, and messages to OpenAI
- Parses responses (`tool_calls` or legacy `function_call`)
- Wraps tool results to feed back into the conversation

You can later plug in other providers by writing another adapter.

### 6) StoreMemory
A minimal in-memory store that holds past tool call results by thread.  
Swap this for Redis/DB in production to persist across restarts and scale horizontally.

---

## End-to-End Flow
1. **User says**: `"I want a red race car toy for $12"`.
2. **LLM parses intent**: `"create_toy_v1"`.
3. **LLM fills slots**: `price = 1200`, `color = red`. Missing: `name`, `category`.
4. **LLM asks user**: “What’s the name?” → “Supra”.
5. **LLM asks user**: “Is the category car?” → “make it lego”.
6. **Arguments validated** by `Validators`.
7. **Handler called** with `args + context + idempotency_key`.
8. **Result returned**: structured Ruby hash (toy ID, name, category, etc.).
9. **Assistant tells the user**: ✅ Toy created.

---

## Use in your app
- Define your tools (schemas + handlers).
- Register them in the `Registry`.
- Wire the `Orchestrator` with an `Adapter` and a `Store`.
- Pass user messages into `orchestrator.step`.
- Handle outputs (`:assistant` text or `:tool_ran` results).

---

## License
MIT
