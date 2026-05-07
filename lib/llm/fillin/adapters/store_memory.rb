# frozen_string_literal: true

module LlmFillin
  class StoreMemory
    def initialize
      @tool_msgs_by_thread = Hash.new { |hash, key| hash[key] = [] }
    end

    def fetch_tool_messages(thread_id)
      @tool_msgs_by_thread[thread_id]
    end

    def push_tool_message(thread_id, message)
      @tool_msgs_by_thread[thread_id] << message
    end
  end
end
