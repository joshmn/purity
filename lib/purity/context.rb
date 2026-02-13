# frozen_string_literal: true

module Purity
  class UndefinedVariableError < StandardError; end

  class Context
    def initialize(data, strict: false)
      @data = data || {}
      @strict = strict
    end

    def [](key)
      wrap(@data[key.to_s])
    end

    def []=(key, value)
      @data[key.to_s] = value
    end

    def key?(key)
      @data.key?(key.to_s)
    end

    def merge(other)
      self.class.new(@data.merge(other.transform_keys(&:to_s)), strict: @strict)
    end

    def method_missing(name, *args)
      key = name.to_s
      if @data.key?(key)
        wrap(@data[key])
      elsif @strict
        raise UndefinedVariableError, "undefined variable: #{key}"
      else
        nil
      end
    end

    def respond_to_missing?(name, include_private = false)
      true
    end

    def to_s
      ""
    end

    private

    def wrap(val)
      case val
      when Hash then self.class.new(val, strict: @strict)
      when Array then val.map { |v| v.is_a?(Hash) ? self.class.new(v, strict: @strict) : v }
      else val
      end
    end
  end
end
