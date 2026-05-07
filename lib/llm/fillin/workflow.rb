# frozen_string_literal: true

module LlmFillin
  class Workflow
    attr_reader :name, :slots

    def self.define(name, &block)
      new(name).tap { |workflow| workflow.instance_eval(&block) if block }
    end

    def initialize(name)
      @name = name.to_sym
      @slots = SlotSet.new
      @confirm_before_submit = false
      @description = nil
      @handler = nil
    end

    def description(text = nil)
      @description = text if text
      @description
    end

    def slot(name, **options)
      slots.add(Slot.new(name, **options))
    end

    def confirm_before_submit(value = nil)
      @confirm_before_submit = value unless value.nil?
      @confirm_before_submit
    end

    def confirm_before_submit?
      !!@confirm_before_submit
    end

    def handler(&block)
      @handler = block if block
      @handler
    end

    def schema
      Schema.new(slots)
    end

    def to_json_schema
      schema.to_json_schema
    end
  end
end
