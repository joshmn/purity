# frozen_string_literal: true

module Purity

  class Site
    include Template
    include Server

    attr_reader :src, :dest, :config, :helpers_module

    def initialize(src: nil, dest: nil)
      @src = File.expand_path(src || "src")
      @dest_override = dest
      @hooks = Hash.new { |h, k| h[k] = [] }
      @livereload = false
      @build_time = 0
    end

    def hook(name, &block)
      @hooks[name] << block
    end

    def build(include_drafts: false)
      load_plugins
      load_helpers
      @config = load_site
      @dest = File.expand_path(@dest_override || @config.delete("dest") || "build")
      env = ENV.fetch("PURITY_ENV", "development")
      @config["env"] = env
      merge_env_config(env)
      strict = @config.fetch("strict_variables", false)
      @config["data"] = DataStore.new(File.join(@src, "_data"), strict: strict)

      parsed = collect_pages(include_drafts: include_drafts)

      all_pages = parsed.filter_map do |rel, meta, _|
        next if meta["layout"].to_s == "false"
        next if meta["draft"]
        path = output_path(rel: rel, meta: meta)
        page_url = "/#{path}".sub(/index\.html$/, "")
        meta.merge("rel" => rel, "url" => page_url)
      end

      @config["data"]["pages"] = all_pages
      build_collections(parsed: parsed)

      @hooks[:after_parse].each { |fn| fn.call(@config, parsed) }

      parsed.each do |rel, meta, body|
        path = output_path(rel: rel, meta: meta)
        page_url = "/#{path}".sub(/index\.html$/, "")

        page_hash = meta.merge(
          "url" => page_url,
          "og_title" => meta["og_title"] || meta["title"],
          "og_description" => meta["og_description"] || meta["description"]
        )

        ctx = { site: @config, page: page_hash, data: @config["data"] }
        @hooks[:before_render].each { |fn| fn.call(ctx, rel) }
        html = render_page(meta: meta, body: body, context: ctx)
        html = @hooks[:after_render].reduce(html) { |h, fn| fn.call(h, ctx, rel) }
        html = inject_livereload(html: html) if @livereload
        write_output(html: html, rel: path)
        label = meta["layout"].to_s == "false" ? " (standalone)" : ""
        puts("  #{path}#{label}")
      end

      copied = copy_assets
      @hooks[:after_build].each { |fn| fn.call(@config, @dest) }
      stats = "built #{parsed.length} pages"
      stats += ", copied #{copied} assets" if copied > 0
      puts(stats)
    end

    private

    attr_reader :hooks

    def load_plugins
      @hooks.clear
      builtin = File.join(File.dirname(__FILE__), "plugins")
      Dir.glob(File.join(builtin, "*.rb")).sort.each { |f| instance_eval(File.read(f), f) }
      Dir.glob(File.join(@src, "_plugins", "*.rb")).sort.each { |f| instance_eval(File.read(f), f) }
    end

    def load_helpers
      @helpers_module = Module.new
      Dir.glob(File.join(@src, "_helpers", "*.rb")).sort.each do |f|
        @helpers_module.module_eval(File.read(f), f)
      end
    end

    def load_site
      path = File.join(@src, "_site.yml")
      config = File.exist?(path) ? YAML.safe_load(File.read(path), permitted_classes: [Date]) || {} : {}
      config
    end

    def merge_env_config(env)
      envs = @config.delete("environments") || {}
      env_config = envs[env] || {}
      @config.merge!(env_config)
    end

    def parse(path)
      raw = File.read(path)
      return [{}, raw] unless raw.start_with?("---\n")

      parts = raw.split("---\n", 3)
      [YAML.safe_load(parts[1], permitted_classes: [Date]) || {}, parts[2] || ""]
    end

    def collect_pages(include_drafts:)
      Dir.glob(File.join(@src, "**/*.{html,md}"))
        .reject { |f| File.basename(f).start_with?("_") }
        .sort
        .filter_map do |path|
          rel = path.sub("#{@src}/", "")
          meta, body = parse(path)
          meta["format"] = File.extname(rel).delete_prefix(".")
          rel = rel.sub(/\.md$/, ".html")
          next if meta["draft"] && !include_drafts
          meta["excerpt"] ||= extract_excerpt(body)
          [rel, meta, body]
        end
    end

    def extract_excerpt(body)
      if body.include?("<!-- more -->")
        body.split("<!-- more -->", 2).first.strip
      else
        first_para = body.strip.split(/\n\n/, 2).first
        first_para&.strip || ""
      end
    end

    def build_collections(parsed:)
      collections_config = @config.fetch("collections", {})
      return unless collections_config

      collections_config.each do |name, opts|
        opts ||= {}
        items = parsed.filter_map do |rel, meta, _|
          next unless rel.start_with?("#{name}/")
          next if meta["draft"]
          path = output_path(rel: rel, meta: meta)
          page_url = "/#{path}".sub(/index\.html$/, "")
          meta.merge("rel" => rel, "url" => page_url)
        end
        if opts["sort_by"]
          items.sort_by! { |p| p[opts["sort_by"]].to_s }
          items.reverse! if opts["order"] == "desc"
        end
        @config["data"][name] = items
      end
    end

    def output_path(rel:, meta:)
      if meta["permalink"]
        p = meta["permalink"].sub(/^\//, "")
        return "index.html" if p.empty?
        return p.end_with?("/") ? "#{p}index.html" : p
      end

      return rel unless @config.fetch("clean_urls", true)
      return rel if File.basename(rel) == "index.html"
      return rel if File.basename(rel, ".html").match?(/\A\d{3}\z/)

      rel.sub(/\.html$/, "/index.html")
    end

    def write_output(html:, rel:)
      out = File.join(@dest, rel)
      FileUtils.mkdir_p(File.dirname(out))
      File.write(out, html)
    end

    def copy_assets
      count = 0
      Dir.glob(File.join(@src, "**/*"), File::FNM_DOTMATCH)
        .select { |f| File.file?(f) }
        .each do |path|
          rel = path.sub("#{@src}/", "")
          next if rel.end_with?(".html", ".md")
          next if rel.split("/").any? { |seg| seg.start_with?("_") }

          out = File.join(@dest, rel)
          FileUtils.mkdir_p(File.dirname(out))
          FileUtils.cp(path, out)
          count += 1
        end
      count
    end

  end
end
