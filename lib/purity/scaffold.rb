# frozen_string_literal: true

module Purity

  class Scaffold
    def initialize(dir)
      @dir = File.expand_path(dir)
      @src = File.join(@dir, "src")
    end

    def run
      if Dir.exist?(@dir) && !Dir.empty?(@dir)
        puts("#{@dir} already exists and is not empty")
        return false
      end

      create_directories
      create_gemfile
      create_site_config
      create_layout
      create_index
      puts("created #{@dir}")
      puts("  cd #{File.basename(@dir)} && purity watch")
      true
    end

    private

    def create_directories
      FileUtils.mkdir_p(File.join(@src, "_plugins"))
      FileUtils.mkdir_p(File.join(@src, "_helpers"))
    end

    def create_gemfile
      File.write(File.join(@dir, "Gemfile"), <<~RUBY)
        source "https://rubygems.org"

        gem "purity"
      RUBY
    end

    def create_site_config
      File.write(File.join(@src, "_site.yml"), <<~YAML)
        site_name: my site
        description: a site built with purity
      YAML
    end

    def create_layout
      File.write(File.join(@src, "_layout.html"), <<~'HTML')
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title><%= page.title %></title>
          <%= content_for :head %>
        </head>
        <body>
          <%= page.content %>
          <%= content_for :scripts %>
        </body>
        </html>
      HTML
    end

    def create_index
      File.write(File.join(@src, "index.html"), <<~'HTML')
        ---
        title: home
        ---
        <h1><%= page.title %></h1>
        <p>edit src/index.html to get started.</p>
      HTML
    end
  end
end
