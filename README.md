# llm-fillin

**LLM-powered slot filling + tool orchestration for Ruby.**  
Register JSON-schema tools, let an LLM ask for missing fields, then call your handlers safely.

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

## How it works
1. You type a natural request (`"I want a red race car toy for $12"`).
2. The LLM recognizes intent (`create_toy_v1`) and extracts what it can:
   - name = missing
   - category = inferred, but asks for confirmation
   - price = 1200 minor units
   - color = red
3. The assistant asks follow-up questions until all required fields are filled.
4. When ready, the tool handler runs and returns a structured object with the toy’s details.

---

## Use in your app
- Register your own tools in the `Registry` (e.g. `create_invoice`, `create_user`, `lookup_balance`).
- Pass messages into the `Orchestrator`.
- The orchestrator ensures:
  - JSON schema validation
  - tenant/actor context passed into handlers
  - idempotency keys for safe “create” operations
