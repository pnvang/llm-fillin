# frozen_string_literal: true

require "date"
require "time"

module LlmFillin
  class Slot
    VALID_TYPES = %i[string integer number float boolean date datetime array hash].freeze
    EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

    attr_reader :name, :type, :format, :enum, :description, :question, :options

    def initialize(name, type: :string, required: false, format: nil, enum: nil, description: nil, question: nil, **options)
      @name = name.to_sym
      @type = type.to_sym
      @required = required
      @format = format&.to_sym
      @enum = enum
      @description = description
      @question = question
      @options = options

      raise ArgumentError, "Unsupported slot type: #{@type.inspect}" unless VALID_TYPES.include?(@type)
    end

    def required?
      !!@required
    end

    def optional?
      !required?
    end

    def human_name
      name.to_s.tr("_", " ")
    end

    def blank?(value)
      value.nil? || (value.is_a?(String) && value.strip.empty?)
    end

    def follow_up_question
      return question if question

      if enum
        return "Which #{human_name} should I use: #{enum.join(', ')}?"
      end

      return "Is #{human_name} yes or no?" if type == :boolean

      "What is the #{human_name}?"
    end

    def invalid_message
      case format
      when :email
        "Please provide a valid #{human_name}."
      else
        "Please provide a valid #{human_name}."
      end
    end

    def coerce(value)
      return value if blank?(value)

      case type
      when :string
        value.to_s
      when :integer
        value.is_a?(Integer) ? value : Integer(value)
      when :number, :float
        value.is_a?(Numeric) ? value : Float(value)
      when :boolean
        coerce_boolean(value)
      when :date
        coerce_date(value)
      when :datetime
        coerce_datetime(value)
      when :array
        value.is_a?(Array) ? value : Array(value)
      when :hash
        value
      else
        value
      end
    rescue ArgumentError, TypeError
      value
    end

    def valid_value?(value)
      return true if blank?(value) && optional?
      return false if blank?(value) && required?

      type_valid?(value) && enum_valid?(value) && format_valid?(value)
    end

    def validation_errors(value)
      errors = []

      if blank?(value)
        errors << "is required" if required?
        return errors
      end

      errors << "must be a #{type_name}" unless type_valid?(value)
      errors << "must be one of #{enum.join(', ')}" unless enum_valid?(value)
      errors << "must be a valid #{format}" unless format_valid?(value)

      errors
    end

    def to_json_schema
      schema = { "type" => json_schema_type }
      schema["format"] = json_schema_format if json_schema_format
      schema["enum"] = enum if enum
      schema["description"] = description if description

      options.each do |key, value|
        schema[key.to_s] = value if json_schema_option?(key)
      end

      schema
    end

    private

    def type_name
      type == :float ? "number" : type.to_s
    end

    def type_valid?(value)
      case type
      when :string
        value.is_a?(String)
      when :integer
        value.is_a?(Integer)
      when :number, :float
        value.is_a?(Numeric)
      when :boolean
        value == true || value == false
      when :date
        valid_date?(value)
      when :datetime
        valid_datetime?(value)
      when :array
        value.is_a?(Array)
      when :hash
        value.is_a?(Hash)
      else
        true
      end
    end

    def enum_valid?(value)
      return true unless enum

      enum.include?(value)
    end

    def format_valid?(value)
      case format
      when nil
        true
      when :email
        value.is_a?(String) && value.match?(EMAIL_FORMAT)
      when :date
        valid_date?(value)
      when :datetime
        valid_datetime?(value)
      else
        true
      end
    end

    def coerce_boolean(value)
      return value if value == true || value == false

      normalized = value.to_s.strip.downcase
      return true if %w[true yes y 1 on].include?(normalized)
      return false if %w[false no n 0 off].include?(normalized)

      value
    end

    def coerce_date(value)
      return value.iso8601 if value.respond_to?(:iso8601) && value.respond_to?(:year)

      Date.iso8601(value.to_s).iso8601
    end

    def coerce_datetime(value)
      return value.iso8601 if value.respond_to?(:iso8601)

      Time.iso8601(value.to_s).iso8601
    end

    def valid_date?(value)
      Date.iso8601(value.to_s)
      true
    rescue ArgumentError
      false
    end

    def valid_datetime?(value)
      Time.iso8601(value.to_s)
      true
    rescue ArgumentError
      false
    end

    def json_schema_type
      case type
      when :integer
        "integer"
      when :number, :float
        "number"
      when :boolean
        "boolean"
      when :array
        "array"
      when :hash
        "object"
      else
        "string"
      end
    end

    def json_schema_format
      return "date" if type == :date
      return "date-time" if type == :datetime

      format&.to_s
    end

    def json_schema_option?(key)
      %i[minimum maximum minLength maxLength pattern items properties additionalProperties].include?(key)
    end
  end
end
