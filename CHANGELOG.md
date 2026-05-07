# Changelog

## 0.2.0

- Repositioned the gem around Rails-native AI intake forms and slot-filling workflows.
- Added the `LlmFillin.define` workflow DSL with slots, validation, confirmation, handlers, and result objects.
- Added structured result statuses for collecting, clarification, confirmation, validation failures, execution, and errors.
- Added idempotent handler execution with generated idempotency keys and an in-memory store.
- Added pluggable provider adapters: fake, OpenAI, and optional RubyLLM.
- Made provider SDKs optional so the core gem is not tied to one LLM vendor.
- Added example workflows for support tickets, booking leads, and quote requests.
- Added tests that run without API keys.

## 0.1.1

- Original JSON-schema tool registration and OpenAI tool-call orchestration API.
