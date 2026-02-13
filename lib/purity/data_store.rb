# frozen_string_literal: true

module Purity
  class DataStore
    def initialize(dir, strict: false)
      @dir = dir
      @cache = {}
      @strict = strict
    end

    def [](key)
      raw = raw_get(key.to_s)
      wrap(raw)
    end

    def []=(key, value)
      @cache[key.to_s] = value
    end

    def key?(key)
      @cache.key?(key.to_s) || !!find_file(key.to_s)
    end

    def empty?
      !Dir.exist?(@dir) || Dir.glob(File.join(@dir, "**/*.{yml,yaml,json}")).empty?
    end

    def to_s
      ""
    end

    def method_missing(name, *args)
      key = name.to_s
      if @cache.key?(key) || find_file(key)
        self[key]
      elsif @strict
        raise UndefinedVariableError, "undefined data key: #{key}"
      else
        nil
      end
    end

    def respond_to_missing?(name, include_private = false)
      true
    end

    private

    def raw_get(key)
      return @cache[key] if @cache.key?(key)
      path = find_file(key)
      return nil unless path
      @cache[key] = parse(path)
    end

    def find_file(key)
      base = File.join(@dir, key.tr(".", "/"))
      %w[.yml .yaml .json].each do |ext|
        path = "#{base}#{ext}"
        return path if File.exist?(path)
      end
      nil
    end

    def parse(path)
      content = File.read(path)
      if path.end_with?(".json")
        JSON.parse(content)
      else
        YAML.safe_load(content, permitted_classes: [Date])
      end
    end

    def wrap(val)
      case val
      when Hash then Context.new(val, strict: @strict)
      when Array then val.map { |v| v.is_a?(Hash) ? Context.new(v, strict: @strict) : v }
      else val
      end
    end
  end
end
