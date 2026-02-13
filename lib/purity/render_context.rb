# frozen_string_literal: true

module Purity
  class RenderContext
    def initialize(site:, context: {}, content_for_blocks: {}, strict: false)
      @_site = site
      @_context = context
      @_content_for = content_for_blocks
      @_strict = strict
      @_erbout = +""
      extend(site.helpers_module) if site.helpers_module
    end

    def content_for(name, &block)
      key = name.to_s
      if block
        @_content_for[key] = capture(&block)
        ""
      else
        @_content_for[key] || ""
      end
    end

    def content_for?(name)
      @_content_for.key?(name.to_s) && !@_content_for[name.to_s].empty?
    end

    def partial(name, **locals)
      path = File.join(@_site.src, name)
      return "" unless File.exist?(path)
      _, body = @_site.send(:parse, path)
      merged = @_context.dup
      merged[:page] = (merged[:page] || {}).merge(locals.transform_keys(&:to_s))
      @_site.send(:erb_render, body, context: merged, content_for_blocks: @_content_for)
    end

    def get_binding
      binding
    end

    def method_missing(name, *args)
      if @_strict
        raise UndefinedVariableError, "undefined variable: #{name}"
      else
        nil
      end
    end

    def respond_to_missing?(name, include_private = false)
      true
    end

    private

    def capture(&block)
      old = @_erbout
      @_erbout = +""
      block.call
      result = @_erbout
      @_erbout = old
      result
    end
  end
end
