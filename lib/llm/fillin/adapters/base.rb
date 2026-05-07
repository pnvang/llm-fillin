# frozen_string_literal: true

module LlmFillin
  module Adapters
    class Base
      def extract(workflow:, message:, slots:, context:)
        raise NotImplementedError, "#{self.class} must implement #extract"
      end
    end
  end
end
