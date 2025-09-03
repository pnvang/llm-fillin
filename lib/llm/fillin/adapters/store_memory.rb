# frozen_string_literal: true
module LLM
  module Fillin
    class StoreMemory
      def initialize
        @tool_msgs_by_thread = Hash.new { |h,k| h[k] = [] }
      end
      def fetch_tool_messages(thread_id) = @tool_msgs_by_thread[thread_id]
      def push_tool_message(thread_id, msg) = @tool_msgs_by_thread[thread_id] << msg
    end
  end
end
