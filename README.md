# llm-fillin

**LLM-powered slot filling + tool orchestration for Ruby.**  
Register JSON-schema tools, let an LLM ask for missing fields, then call your handlers safely.

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

Try:
```
I want a red race car toy for $12
```

The assistant will ask for any missing fields (like category) and then “create” the toy.

## Use in your app
- Register tools (schemas + handlers)
- Call the Orchestrator with your message list
- Validate server-side; enforce tenant/RBAC; generate idempotency for creates
