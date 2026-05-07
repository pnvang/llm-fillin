# llm-fillin

Ruby core for Rails-native AI intake forms and slot-filling workflows.

`llm-fillin` turns messy user messages into structured Ruby actions. Define the fields your backend needs, let an LLM extract candidate values, validate them, ask concise follow-up questions, confirm with the user, and execute your handler once.

It is framework-light Ruby, designed to power Rails apps. It is not a broad agent framework.

## Why Slot Filling

Generic chatbots are open-ended. Intake workflows are constrained.

With `llm-fillin`, your app owns the workflow:

- Required fields are explicit.
- Values are validated before backend code runs.
- Missing or invalid slots become follow-up questions.
- Confirmation can be required before submit.
- Handlers run behind idempotency keys to avoid duplicate backend actions.

## Installation

```ruby
gem "llm-fillin"
```

Then:

```bash
bundle install
```

Provider SDKs are optional. Add `gem "openai"` or `gem "ruby_llm"` in your app only when you use those adapters.

## Define An Intake Workflow

```ruby
require "llm/fillin"

LlmFillin.define(:booking_lead) do
  description "Collect event details before creating a booking lead"

  slot :name, type: :string, required: true
  slot :email, type: :string, required: true, format: :email
  slot :event_date, type: :date, required: true
  slot :start_time, type: :string, required: true
  slot :end_time, type: :string, required: true
  slot :location, type: :string, required: true
  slot :guest_count, type: :integer, required: false
  slot :package, type: :string, enum: ["Gold", "Platinum", "Emerald"], required: false
  slot :backdrop, type: :string, required: false
  slot :tax_exempt, type: :boolean, required: false

  confirm_before_submit true

  handler do |values, context|
    BookingLead.create!(
      values.merge(
        account_id: context[:tenant_id],
        created_by_id: context[:actor_id],
        idempotency_key: context[:idempotency_key]
      )
    )
  end
end
```

## Run A Conversation Step

```ruby
workflow = LlmFillin.workflow(:booking_lead)
adapter = LlmFillin::Adapters::OpenAI.new(
  api_key: ENV.fetch("OPENAI_API_KEY"),
  model: "gpt-4.1-mini"
)

intake = LlmFillin::Intake.new(workflow, adapter: adapter)

result = intake.step(
  "I need a Gold package for 75 guests on June 20 from 6 to 10.",
  state: session[:booking_lead_intake],
  context: {
    tenant_id: current_account.id,
    actor_id: current_user.id,
    thread_id: session.id
  }
)

session[:booking_lead_intake] = result.state
render json: result.to_h
```

## Handling Missing Fields

If required slots are missing, the result is structured for Rails to render:

```ruby
result.status        #=> :needs_clarification
result.message       #=> "What is the email?"
result.slots         #=> { name: "Mina", event_date: "2026-06-20" }
result.missing_slots #=> [:email, :start_time, :end_time, :location]
```

## Validation

Slots are validated before handlers run. Supported slot options include `type`, `required`, `format: :email`, and `enum`.

```ruby
result.status        #=> :invalid
result.invalid_slots #=> { email: ["must be a valid email"] }
result.message       #=> "Please provide a valid email."
```

Each workflow can also expose a JSON schema:

```ruby
LlmFillin.workflow(:booking_lead).to_json_schema
```

## Confirmation Before Execution

When `confirm_before_submit true` is set, the workflow pauses after all required slots are valid:

```ruby
result.status
#=> :needs_confirmation

result.ready_to_confirm?
#=> true
```

Send the next user message with the saved state:

```ruby
confirmed = intake.step("yes", state: result.state, context: context)

confirmed.status
#=> :executed

confirmed.execution_result
#=> # handler return value
```

## Idempotency

Every ready workflow gets an idempotency key derived from workflow name, context, and values unless you pass one explicitly.

```ruby
result.idempotency_key
#=> "intake-..."
```

The default in-memory idempotency store prevents duplicate execution inside a process. In Rails, pass a persistent store with `fetch(key)` and `store(key, execution)` if duplicate protection must survive process restarts:

```ruby
store = MyRedisBackedIdempotencyStore.new
intake = LlmFillin::Intake.new(workflow, adapter: adapter, idempotency: store)
```

The result state also records completed execution data, so saving `result.state` in a session or conversation row helps prevent double-submit retries.

## Result Object

```ruby
result.status              # :collecting, :needs_clarification, :needs_confirmation, :invalid, :executed, :error
result.message             # concise user-facing next step
result.slots               # filled and coerced values
result.missing_slots       # required slots still missing
result.invalid_slots       # invalid slot errors
result.ready_to_confirm?   # true when valid values need user confirmation
result.ready_to_execute?   # true when validation and confirmation have passed
result.executed?           # true after handler completion or idempotent replay
result.execution_result    # handler return value
result.idempotency_key     # stable key for this submission
result.to_h                # JSON-friendly hash
```

## Provider Adapters

Adapters are intentionally small. The core gem asks an adapter to extract slots:

```ruby
adapter.extract(
  workflow: workflow,
  message: "My email is mina@example.com",
  slots: {},
  context: {}
)
#=> { email: "mina@example.com" }
```

Included adapters:

- `LlmFillin::Adapters::Fake` for tests and demos.
- `LlmFillin::Adapters::OpenAI` for OpenAI, optional `openai` gem required.
- `LlmFillin::Adapters::RubyLLM` for RubyLLM, optional `ruby_llm` gem required.

Custom adapters can subclass `LlmFillin::Adapters::Base` and implement `#extract`.

## Minimal Rails Controller Shape

```ruby
class IntakeStepsController < ApplicationController
  def create
    intake = LlmFillin::Intake.new(
      LlmFillin.workflow(params[:workflow_name]),
      adapter: Rails.application.config.x.llm_fillin_adapter,
      idempotency: Rails.application.config.x.llm_fillin_idempotency
    )

    result = intake.step(
      params[:message],
      state: session["intake_#{params[:workflow_name]}"],
      context: {
        tenant_id: current_account.id,
        actor_id: current_user.id,
        thread_id: session.id
      }
    )

    session["intake_#{params[:workflow_name]}"] = result.state
    render json: result.to_h
  end
end
```

Rails-specific engine behavior belongs in `llm-agent-rails`; this gem stays small and Ruby-ish.

## How This Relates To llm-agent-rails

`llm-fillin` is the framework-light Ruby core: workflow definitions, slot validation, confirmation, result objects, provider adapters, and idempotent handler execution.

`llm-agent-rails` adds the Rails-native layer: autoloaded intake classes, ActiveRecord persistence, JSON endpoints, Rails generators, and dummy/demo app patterns.

## Examples

- `examples/support_ticket_intake.rb`
- `examples/booking_lead_intake.rb`
- `examples/quote_request_intake.rb`

All examples use the fake adapter and require no API keys.

## Backwards Compatibility

The 0.1 `LLM::Fillin` namespace, JSON-schema tool registry, and tool-call orchestrator remain available where practical. The 0.2 API is `LlmFillin.define` plus intake workflows.

## Tests

```bash
bundle exec ruby -Itest -Ilib test/intake_workflow_test.rb
```

No API keys are required.

## License

MIT
