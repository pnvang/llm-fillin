# frozen_string_literal: true

require "json"

module LlmFillin
  class Orchestrator
    POLICY = <<~SYS
      You are a task-oriented assistant. Identify intent, extract entities,
      ask for missing required fields one at a time, and call exactly one function when ready.
      Keep replies concise and friendly.
    SYS

    def initialize(adapter:, workflow: nil, registry: nil, store: nil, idempotency: nil)
      @adapter = adapter
      @workflow = workflow
      @registry = registry
      @store = store
      @idempotency = idempotency || Idempotency::MemoryStore.new
    end

    def step(message = nil, state: nil, context: {}, idempotency_key: nil, confirm: nil, **legacy_args)
      return intake_step(message || legacy_args[:message], state: state, context: context, idempotency_key: idempotency_key, confirm: confirm, messages: legacy_args[:messages]) if @workflow

      legacy_step(**legacy_args)
    end

    private

    def intake_step(message, state:, context:, idempotency_key:, confirm:, messages: nil)
      message ||= last_user_message(messages)
      current_state = normalize_state(state)
      current_slots = current_state.fetch(:slots)

      if blank?(message) && current_slots.empty?
        return result(
          status: :collecting,
          message: @workflow.description || "Tell me what you would like to submit.",
          slots: {},
          confirmed: false,
          idempotency_key: idempotency_key || current_state[:idempotency_key],
          state_executed: current_state[:executed],
          state_execution_result: current_state[:execution_result]
        )
      end

      confirmation_signal = confirm.nil? ? affirmative_confirmation?(message) : !!confirm
      negative_signal = negative_confirmation?(message)
      extracted = pure_confirmation?(message) ? {} : adapter_extract(message, current_slots, context)
      extracted = known_slots(extracted)
      slots_changed = extracted.any? { |name, value| current_slots[name] != value }

      merged_slots = current_slots.merge(extracted)
      validation = @workflow.schema.validate(merged_slots)
      values = validation.values
      confirmed = current_state[:confirmed]
      confirmed = false if slots_changed

      key = idempotency_key || current_state[:idempotency_key]
      key = nil if slots_changed
      key ||= Idempotency.generate(workflow: @workflow, context: context, values: values)

      if validation.invalid_slots.any?
        return result(
          status: :invalid,
          message: invalid_message(validation.invalid_slots),
          slots: values,
          missing_slots: validation.missing_slots,
          invalid_slots: validation.invalid_slots,
          confirmed: false,
          idempotency_key: key
        )
      end

      if validation.missing_slots.any?
        return result(
          status: :needs_clarification,
          message: clarification_message(validation.missing_slots),
          slots: values,
          missing_slots: validation.missing_slots,
          confirmed: false,
          idempotency_key: key
        )
      end

      if @workflow.confirm_before_submit?
        return needs_change_result(values, key) if negative_signal

        confirmed ||= confirmation_signal
        return confirmation_result(values, key) unless confirmed
      else
        confirmed = true
      end

      execute(values, context, key, current_state)
    end

    def adapter_extract(message, slots, context)
      @adapter.extract(workflow: @workflow, message: message.to_s, slots: slots, context: context) || {}
    end

    def known_slots(values)
      values.each_with_object({}) do |(key, value), out|
        name = key.to_sym
        out[name] = value if @workflow.slots[name]
      end
    end

    def execute(values, context, idempotency_key, current_state)
      if current_state[:executed] && current_state[:idempotency_key] == idempotency_key
        execution = Execution.duplicate(idempotency_key: idempotency_key, result: current_state[:execution_result])
        return result(status: :executed, message: "Already submitted.", slots: values, confirmed: true, execution: execution, idempotency_key: idempotency_key)
      end

      if (stored = @idempotency.fetch(idempotency_key))
        execution = Execution.duplicate(idempotency_key: idempotency_key, result: stored.result)
        return result(status: :executed, message: "Already submitted.", slots: values, confirmed: true, execution: execution, idempotency_key: idempotency_key)
      end

      raise ArgumentError, "Workflow #{@workflow.name.inspect} does not define a handler" unless @workflow.handler

      handler_context = context.merge(idempotency_key: idempotency_key, workflow_name: @workflow.name)
      output = @workflow.handler.call(values, handler_context)
      execution = Execution.completed(idempotency_key: idempotency_key, result: output)
      @idempotency.store(idempotency_key, execution)

      result(status: :executed, message: "Submitted.", slots: values, confirmed: true, execution: execution, idempotency_key: idempotency_key)
    rescue StandardError => e
      execution = Execution.failed(idempotency_key: idempotency_key, error: e)
      result(status: :error, message: e.message, slots: values, confirmed: true, execution: execution, idempotency_key: idempotency_key)
    end

    def result(status:, message:, slots:, missing_slots: [], invalid_slots: {}, confirmed:, execution: nil,
               idempotency_key:, state_executed: nil, state_execution_result: nil)
      Result.new(
        status: status,
        message: message,
        workflow: @workflow,
        slots: slots,
        missing_slots: missing_slots,
        invalid_slots: invalid_slots,
        confirmed: confirmed,
        execution: execution,
        idempotency_key: idempotency_key,
        state: build_state(slots, confirmed, idempotency_key, execution, state_executed, state_execution_result)
      )
    end

    def build_state(slots, confirmed, idempotency_key, execution, state_executed, state_execution_result)
      executed = execution&.completed? || state_executed || false
      execution_result = execution&.result || state_execution_result

      {
        "workflow" => @workflow.name.to_s,
        "slots" => stringify_keys(slots),
        "confirmed" => !!confirmed,
        "idempotency_key" => idempotency_key,
        "executed" => executed,
        "execution_result" => execution_result
      }
    end

    def needs_change_result(values, key)
      result(
        status: :needs_clarification,
        message: "What should I change before submitting?",
        slots: values,
        confirmed: false,
        idempotency_key: key
      )
    end

    def confirmation_result(values, key)
      result(
        status: :needs_confirmation,
        message: confirmation_message(values),
        slots: values,
        confirmed: false,
        idempotency_key: key
      )
    end

    def invalid_message(invalid_slots)
      slot_name = invalid_slots.keys.first
      @workflow.slots[slot_name].invalid_message
    end

    def clarification_message(missing_slots)
      @workflow.slots[missing_slots.first].follow_up_question
    end

    def confirmation_message(values)
      filled = @workflow.slots.filled(values)
      summary = filled.map { |name| "#{@workflow.slots[name].human_name}: #{format_value(values[name])}" }.join(", ")

      summary.empty? ? "Should I submit this?" : "Please confirm: #{summary}. Should I submit this?"
    end

    def format_value(value)
      case value
      when true
        "yes"
      when false
        "no"
      when Array
        value.join(", ")
      else
        value.to_s
      end
    end

    def normalize_state(state)
      raw = state || {}
      slots = read_key(raw, :slots) || {}

      {
        slots: known_slots(slots),
        confirmed: !!read_key(raw, :confirmed),
        idempotency_key: read_key(raw, :idempotency_key),
        executed: !!read_key(raw, :executed),
        execution_result: read_key(raw, :execution_result)
      }
    end

    def read_key(hash, key)
      return hash[key] if hash.key?(key)
      return hash[key.to_s] if hash.key?(key.to_s)

      nil
    end

    def stringify_keys(hash)
      hash.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:strip) && value.strip.empty?)
    end

    def pure_confirmation?(message)
      affirmative_confirmation?(message) || negative_confirmation?(message)
    end

    def affirmative_confirmation?(message)
      message.to_s.strip.downcase.match?(/\A(yes|y|yeah|yep|correct|confirm|confirmed|submit|looks good|ok|okay|do it)\z/)
    end

    def negative_confirmation?(message)
      message.to_s.strip.downcase.match?(/\A(no|n|nope|not yet|cancel|stop)\z/)
    end

    def last_user_message(messages)
      Array(messages).reverse.find { |message| (message[:role] || message["role"]).to_s == "user" }&.then { |message| message[:content] || message["content"] }
    end

    # 0.1 orchestration, retained for existing users.
    def legacy_step(thread_id:, tenant_id:, actor_id:, messages:)
      prior_tool_msgs = @store.fetch_tool_messages(thread_id)

      response = @adapter.step(
        system_prompt: POLICY,
        messages: messages,
        tools: @registry.tools_for_llm,
        tool_results: prior_tool_msgs
      )

      if (calls = response[:tool_calls]).is_a?(Array) && calls.any?
        call = calls.first
        fn = call.respond_to?(:function) ? call.function : nil
        name = fn&.respond_to?(:name) ? fn.name : nil
        args_json = fn&.respond_to?(:arguments) ? fn.arguments.to_s : "{}"
        args = args_json.empty? ? {} : JSON.parse(args_json)
        tool_name, version = parse_tool_name(name)

        tool = @registry.tool(tool_name, version: version)
        Validators.validate!(tool.schema, args)

        context = { tenant_id: tenant_id, actor_id: actor_id, thread_id: thread_id }
        output = tool.handler.call(args, context)

        tool_msg = @adapter.tool_result_message(
          tool_call_id: call.respond_to?(:id) ? call.id : nil,
          name: "#{tool_name}_#{version}",
          content: output
        )
        @store.push_tool_message(thread_id, tool_msg)

        return { type: :tool_ran, tool_name: tool_name, result: output }
      end

      if (function_call = response[:function_call])
        name_with_version = function_call["name"]
        args_json = function_call["arguments"].to_s
        args = args_json.empty? ? {} : JSON.parse(args_json)
        tool_name, version = parse_tool_name(name_with_version)

        tool = @registry.tool(tool_name, version: version)
        Validators.validate!(tool.schema, args)

        context = { tenant_id: tenant_id, actor_id: actor_id, thread_id: thread_id }
        output = tool.handler.call(args, context)

        return { type: :tool_ran, tool_name: tool_name, result: output }
      end

      { type: :assistant, text: response[:content].to_s }
    end

    def parse_tool_name(name)
      tool_name, version = name.to_s.split(/_v/i, 2)
      [tool_name, version ? "v#{version}" : "v1"]
    end
  end
end
