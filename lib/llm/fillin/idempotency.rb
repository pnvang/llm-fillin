# frozen_string_literal: true
require "securerandom"

module LLM
  module Fillin
    module Idempotency
      def self.generate(thread_id:)
        "chat-#{thread_id}-#{SecureRandom.hex(6)}"
      end
    end
  end
end
