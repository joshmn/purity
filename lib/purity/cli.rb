# frozen_string_literal: true

module Purity

  class CLI
    class << self
      def run(args = ARGV.dup)
        include_drafts = !!args.delete("--drafts")

        case args[0]
        when "new", "n"
          new_site(args[1])
        when "serve", "s"
          ENV["PURITY_ENV"] ||= "development"
          port = args[1] ? args[1].to_i : 4567
          Site.new.serve(port: port)
        when "watch", "w"
          ENV["PURITY_ENV"] ||= "development"
          port = args[1] ? args[1].to_i : 4567
          Site.new.watch(port: port)
        when "help", "h", "-h", "--help"
          help
        when "version", "-v", "--version"
          puts("purity #{VERSION}")
        else
          ENV["PURITY_ENV"] ||= "production"
          Site.new.build(include_drafts: include_drafts)
        end
      end

      private

      def new_site(dir)
        unless dir
          puts("usage: purity new <directory>")
          return
        end
        Scaffold.new(dir).run
      end

      def help
        puts("purity #{VERSION}")
        puts("")
        puts("usage: purity [command] [options]")
        puts("")
        puts("commands:")
        puts("  new <dir>     create a new site")
        puts("  (none)        build the site")
        puts("  serve, s      build and serve on localhost")
        puts("  watch, w      build, serve, and rebuild on changes")
        puts("  help, h       this message")
        puts("  version       show version")
        puts("")
        puts("options:")
        puts("  --drafts      include pages with draft: true")
        puts("  [port]        port for serve/watch (default: 4567)")
        puts("")
        puts("template variables:")
        puts("  site.title          from _site.yml")
        puts("  page.title          from front matter")
        puts("  page.url            clean URL path of the current page")
        puts("  page.content        rendered page body (in layouts)")
        puts("  data.nav            from _data/nav.yml")
        puts("  data.posts          configured collection")
        puts("  data.pages          all non-standalone, non-draft pages")
        puts("")
        puts("front matter:")
        puts("  layout: name    use _name.html (default: _layout.html)")
        puts("  layout: false   copy file as-is, no layout")
        puts("  draft: true     skip unless --drafts")
        puts("  date: YYYY-MM-DD  date for feed generation")
        puts("  permalink: /p/  custom output path")
        puts("")
        puts("config (_site.yml):")
        puts("  url: https://...      enables sitemap + feed generation")
        puts("  site_name: My Site    used in feed title")
        puts("  clean_urls: true      rewrite to clean URLs (default)")
        puts("  strict_variables: true  raise on undefined variables")
        puts("  collections:          directory-based collections")
        puts("    posts:")
        puts("      sort_by: date")
        puts("      order: desc")
        puts("  environments:         per-environment overrides")
        puts("    production:")
        puts("      strict_variables: false")
        puts("")
        puts("plugins (src/_plugins/*.rb):")
        puts("  hook :after_parse  { |config, pages| }")
        puts("  hook :before_render { |ctx, rel| }")
        puts("  hook :before_layout { |content, meta, ctx| content }")
        puts("  hook :after_render { |html, ctx, rel| html }")
        puts("  hook :after_build  { |config, dest| }")
      end
    end
  end
end
