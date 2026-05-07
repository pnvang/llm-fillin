# frozen_string_literal: true

module LlmFillin
  class SlotSet
    include Enumerable

    def initialize(slots = [])
      @slots = {}
      slots.each { |slot| add(slot) }
    end

    def add(slot)
      raise ArgumentError, "Slot #{slot.name.inspect} is already defined" if @slots.key?(slot.name)

      @slots[slot.name] = slot
      slot
    end

    def each(&block)
      @slots.values.each(&block)
    end

    def [](name)
      @slots[name.to_sym]
    end

    def names
      @slots.keys
    end

    def required
      select(&:required?)
    end

    def optional
      select(&:optional?)
    end

    def coerce(values)
      source = values || {}

      each_with_object({}) do |slot, coerced|
        next unless key?(source, slot.name)

        coerced[slot.name] = slot.coerce(fetch(source, slot.name))
      end
    end

    def filled(values)
      source = values || {}

      names.select do |name|
        slot = self[name]
        key?(source, name) && !slot.blank?(fetch(source, name))
      end
    end

    def missing_required(values)
      source = values || {}

      required.filter_map do |slot|
        slot.name unless key?(source, slot.name) && !slot.blank?(fetch(source, slot.name))
      end
    end

    def to_json_schema
      {
        "type" => "object",
        "additionalProperties" => false,
        "properties" => each_with_object({}) { |slot, props| props[slot.name.to_s] = slot.to_json_schema },
        "required" => required.map { |slot| slot.name.to_s }
      }
    end

    private

    def key?(hash, name)
      hash.key?(name) || hash.key?(name.to_s)
    end

    def fetch(hash, name)
      return hash[name] if hash.key?(name)

      hash[name.to_s]
    end
  end
end
