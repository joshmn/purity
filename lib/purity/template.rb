# frozen_string_literal: true

module Purity
  module Template
    def render(body:, context:)
      erb_render(body, context: context)
    end

    def render_page(meta:, body:, context:)
      return body if meta["layout"].to_s == "false"

      captured = {}
      context[:page]["content"] = erb_render(body, context: context, content_for_blocks: captured)
      context[:page]["content"] = @hooks[:before_layout].reduce(context[:page]["content"]) { |c, fn| fn.call(c, meta, context) }
      apply_layout(meta: meta, context: context, content_for_blocks: captured)
    end

    private

    def erb_render(body, context:, content_for_blocks: {})
      strict = (context[:site] || {}).fetch("strict_variables", false)
      ctx = RenderContext.new(site: self, context: context, content_for_blocks: content_for_blocks, strict: strict)
      b = ctx.get_binding
      b.local_variable_set(:site, Context.new(context[:site] || {}, strict: strict))
      b.local_variable_set(:page, Context.new(context[:page] || {}, strict: strict))
      b.local_variable_set(:data, context[:data]) if context[:data]
      ERB.new(body, trim_mode: "-", eoutvar: "@_erbout").result(b)
    end

    def apply_layout(meta:, context:, content_for_blocks: {})
      layout_name = meta.key?("layout") ? meta["layout"] : "layout"
      lpath = File.join(src, "_#{layout_name}.html")
      return context[:page]["content"] unless File.exist?(lpath)

      lmeta, lbody = parse(lpath)
      result = erb_render(lbody, context: context, content_for_blocks: content_for_blocks)
      while lmeta["layout"]
        context[:page]["content"] = result
        lp = File.join(src, "_#{lmeta['layout']}.html")
        break unless File.exist?(lp)
        lmeta, lbody = parse(lp)
        result = erb_render(lbody, context: context, content_for_blocks: content_for_blocks)
      end
      result
    end
  end
end
