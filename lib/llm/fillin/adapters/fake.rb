# frozen_string_literal: true

module LlmFillin
  module Adapters
    class Fake < Base
      def initialize(responses: [], extractor: nil)
        @responses = responses.dup
        @extractor = extractor
      end

      def extract(workflow:, message:, slots:, context:)
        if @extractor
          return @extractor.call(workflow: workflow, message: message, slots: slots, context: context)
        end

        @responses.empty? ? {} : @responses.shift
      end
    end
  end
end
