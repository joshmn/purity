# frozen_string_literal: true

require "test_helper"

module Purity
  class SiteTest < Minitest::Test
    def setup
      @dir = Dir.mktmpdir
      @src = File.join(@dir, "src")
      @dest = File.join(@dir, "build")
      FileUtils.mkdir_p(@src)
    end

    def teardown
      FileUtils.rm_rf(@dir)
    end

    def test_basic_build
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Test", body: "Hello")

      build_site
      assert_output_includes("index.html", "Hello")
    end

    def test_layout_wraps_content
      write_layout("<html><%= page.content %></html>")
      write_page("index.html", title: "Test", body: "Hello")

      build_site
      assert_output_includes("index.html", "<html>Hello</html>")
    end

    def test_standalone_page
      write_page("raw.html", layout: false, body: "<p>Raw</p>")

      build_site
      assert_equal("<p>Raw</p>", read_output("raw/index.html"))
    end

    def test_site_yml_variables
      write_site_yml("site_name: Test Site")
      write_layout("<%= site.site_name %>: <%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")

      build_site
      assert_output_includes("index.html", "Test Site: Hello")
    end

    def test_page_and_site_vars_are_separate
      write_site_yml("greeting: default")
      write_layout("<%= site.greeting %> / <%= page.greeting %>: <%= page.content %>")
      write_page("index.html", greeting: "custom", body: "Hello")

      build_site
      assert_output_includes("index.html", "default / custom: Hello")
    end

    def test_partials
      write_layout("<%= page.content %>")
      File.write(File.join(@src, "_header.html"), "<h1><%= page.title %></h1>")
      write_page("index.html", title: "Hi", body: '<%= partial "_header.html" %>')

      build_site
      assert_output_includes("index.html", "<h1>Hi</h1>")
    end

    def test_conditionals_in_layout
      write_layout('<% if page.show_nav %><nav/><% end %><%= page.content %>')
      write_page("index.html", show_nav: true, body: "Hello")
      write_page("plain.html", body: "Plain")

      build_site
      assert_output_includes("index.html", "<nav/>Hello")
      refute_output_includes("plain/index.html", "<nav/>")
    end

    def test_content_for_and_yield
      write_layout("<head><%= content_for :head %></head><body><%= page.content %><%= content_for :scripts %></body>")
      write_page("index.html", title: "Hi", body: "<% content_for :head do %><style>h1{}</style><% end %><% content_for :scripts do %><script>1</script><% end %>Hello")

      build_site
      output = read_output("index.html")
      assert_includes(output, "<head><style>h1{}</style></head>")
      assert_includes(output, "<script>1</script>")
      assert_includes(output, "Hello")
    end

    def test_nested_layouts
      write_layout("<html><%= page.content %></html>")
      write_file("_post.html", "---\nlayout: layout\n---\n<article><%= page.content %></article>")
      write_page("index.html", layout: "post", body: "Hello")

      build_site
      assert_output_includes("index.html", "<html><article>Hello</article></html>")
    end

    def test_sitemap_generated_when_url_set
      write_site_yml("url: https://example.com")
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")

      build_site
      assert(File.exist?(File.join(@dest, "sitemap.xml")))
      assert_includes(read_output("sitemap.xml"), "https://example.com/")
    end

    def test_feed_generated_when_url_set
      write_site_yml("url: https://example.com\nsite_name: Test")
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", date: "2024-01-01", body: "Hello")

      build_site
      assert(File.exist?(File.join(@dest, "feed.xml")))
    end

    def test_no_sitemap_without_url
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")

      build_site
      refute(File.exist?(File.join(@dest, "sitemap.xml")))
    end

    def test_drafts_skipped_by_default
      write_layout("<%= page.content %>")
      write_page("draft.html", title: "Draft", draft: true, body: "Secret")

      build_site
      refute(File.exist?(File.join(@dest, "draft", "index.html")))
    end

    def test_drafts_included_when_requested
      write_layout("<%= page.content %>")
      write_page("draft.html", title: "Draft", draft: true, body: "Secret")

      build_site(include_drafts: true)
      assert(File.exist?(File.join(@dest, "draft", "index.html")))
    end

    def test_permalink
      write_layout("<%= page.content %>")
      write_page("post.html", title: "Post", permalink: "/blog/my-post/", body: "Content")

      build_site
      assert(File.exist?(File.join(@dest, "blog", "my-post", "index.html")))
    end

    def test_dest_from_site_yml
      custom_dest = File.join(@dir, "custom_output")
      write_site_yml("dest: #{custom_dest}")
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")

      site = Purity::Site.new(src: @src)
      capture_io { site.build }
      assert(File.exist?(File.join(custom_dest, "index.html")))
    end

    def test_dest_override_beats_site_yml
      write_site_yml("dest: #{File.join(@dir, 'wrong')}")
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")

      build_site
      assert(File.exist?(File.join(@dest, "index.html")))
      refute(File.exist?(File.join(@dir, "wrong", "index.html")))
    end

    def test_plugin_before_render
      FileUtils.mkdir_p(File.join(@src, "_plugins"))
      File.write(File.join(@src, "_plugins", "test.rb"), 'hook(:before_render) { |ctx, _| ctx[:page]["injected"] = "yes" }')
      write_layout("<%= page.injected %>: <%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")

      build_site
      assert_output_includes("index.html", "yes: Hello")
    end

    def test_plugin_after_render
      FileUtils.mkdir_p(File.join(@src, "_plugins"))
      File.write(File.join(@src, "_plugins", "test.rb"), 'hook(:after_render) { |html, _, _| html.gsub("Hello", "Goodbye") }')
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")

      build_site
      assert_output_includes("index.html", "Goodbye")
    end

    def test_og_title_falls_back_to_title
      write_layout('<meta property="og:title" content="<%= page.og_title %>">')
      write_page("index.html", title: "My Title", body: "Hello")

      build_site
      assert_output_includes("index.html", 'content="My Title"')
    end

    def test_root_permalink
      write_layout("<%= page.content %>")
      write_page("home.html", title: "Home", permalink: "/", body: "Welcome")

      build_site
      assert(File.exist?(File.join(@dest, "index.html")))
      assert_output_includes("index.html", "Welcome")
    end

    def test_copies_favicon
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")
      File.write(File.join(@src, "favicon.ico"), "icon-data")

      build_site
      assert(File.exist?(File.join(@dest, "favicon.ico")))
      assert_equal("icon-data", File.read(File.join(@dest, "favicon.ico")))
    end

    def test_copies_css_in_subdirectory
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")
      FileUtils.mkdir_p(File.join(@src, "css"))
      File.write(File.join(@src, "css", "style.css"), "body{}")

      build_site
      assert(File.exist?(File.join(@dest, "css", "style.css")))
    end

    def test_copies_images
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")
      FileUtils.mkdir_p(File.join(@src, "images"))
      File.write(File.join(@src, "images", "logo.png"), "png-data")

      build_site
      assert(File.exist?(File.join(@dest, "images", "logo.png")))
    end

    def test_skips_underscore_dirs_for_assets
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")
      FileUtils.mkdir_p(File.join(@src, "_plugins"))
      File.write(File.join(@src, "_plugins", "test.rb"), "# plugin")

      build_site
      refute(File.exist?(File.join(@dest, "_plugins", "test.rb")))
    end

    def test_skips_underscore_files_for_assets
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")
      File.write(File.join(@src, "_site.yml"), "site_name: test")

      build_site
      refute(File.exist?(File.join(@dest, "_site.yml")))
    end

    def test_asset_count_in_output
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")
      File.write(File.join(@src, "favicon.ico"), "icon")
      File.write(File.join(@src, "robots.txt"), "User-agent: *")

      site = Purity::Site.new(src: @src, dest: @dest)
      output = capture_io { site.build }[0]
      assert_includes(output, "copied 2 assets")
    end

    def test_data_from_yaml
      write_layout("<%= page.content %>")
      FileUtils.mkdir_p(File.join(@src, "_data"))
      File.write(File.join(@src, "_data", "nav.yml"), "- label: Home\n  url: /\n- label: About\n  url: /about/")
      write_page("index.html", title: "Hi", body: '<% data.nav.each do |item| %><a href="<%= item.url %>"><%= item.label %></a><% end %>')

      build_site
      assert_output_includes("index.html", '<a href="/">Home</a>')
      assert_output_includes("index.html", '<a href="/about/">About</a>')
    end

    def test_data_from_json
      write_layout("<%= page.content %>")
      FileUtils.mkdir_p(File.join(@src, "_data"))
      File.write(File.join(@src, "_data", "social.json"), '{"github": "joshmn", "twitter": "joshmn"}')
      write_page("index.html", title: "Hi", body: '<%= data.social.github %>')

      build_site
      assert_output_includes("index.html", "joshmn")
    end

    def test_nested_data_files
      write_layout("<%= page.content %>")
      FileUtils.mkdir_p(File.join(@src, "_data", "i18n"))
      File.write(File.join(@src, "_data", "i18n", "en.yml"), "hello: Hello World")
      write_page("index.html", title: "Hi", body: '<%= data["i18n.en"].hello %>')

      build_site
      assert_output_includes("index.html", "Hello World")
    end

    def test_no_data_dir_is_fine
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")

      build_site
      assert_output_includes("index.html", "Hello")
    end

    def test_md_extension_renders_markdown
      write_markdown_plugin
      write_layout("<%= page.content %>")
      write_page("post.md", title: "Hi", body: "# Hello\n\nThis is **bold**.")

      build_site
      output = read_output("post/index.html")
      assert_includes(output, "<h1>Hello</h1>")
      assert_includes(output, "<strong>bold</strong>")
    end

    def test_md_extension_outputs_html_file
      write_layout("<%= page.content %>")
      write_page("post.md", title: "Hi", body: "# Hello")

      build_site
      assert(File.exist?(File.join(@dest, "post", "index.html")))
      refute(File.exist?(File.join(@dest, "post.md")))
    end

    def test_html_without_markdown_flag_stays_html
      write_layout("<%= page.content %>")
      write_page("post.html", title: "Hi", body: "# Not markdown")

      build_site
      assert_output_includes("post/index.html", "# Not markdown")
    end

    def test_md_with_erb_variables
      write_markdown_plugin
      write_layout("<%= page.content %>")
      write_page("post.md", title: "Hi", body: "# <%= page.title %>\n\nSome text.")

      build_site
      output = read_output("post/index.html")
      assert_includes(output, "<h1>Hi</h1>")
    end

    def test_md_post_in_collection
      write_markdown_plugin
      write_site_yml("collections:\n  posts:\n    sort_by: date\n    order: desc")
      write_layout("<%= page.content %>")
      write_page("posts/a.md", title: "MD Post", date: "2024-06-01", body: "# Hello")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %><%= p.title %>,<% end %>')

      build_site
      assert_output_includes("list/index.html", "MD Post,")
    end

    def test_md_without_plugin_passes_through_raw
      write_layout("<%= page.content %>")
      write_page("post.md", title: "Hi", body: "# Hello\n\nSome **bold** text.")

      build_site
      output = read_output("post/index.html")
      assert_includes(output, "# Hello")
      assert_includes(output, "**bold**")
    end

    def test_md_files_not_copied_as_assets
      write_layout("<%= page.content %>")
      write_page("post.md", title: "Hi", body: "# Hello")

      build_site
      refute(File.exist?(File.join(@dest, "post.md")))
    end

    def test_helper_method_available_in_template
      FileUtils.mkdir_p(File.join(@src, "_helpers"))
      File.write(File.join(@src, "_helpers", "formatting.rb"), <<~RUBY)
        def shout(text)
          text.upcase
        end
      RUBY
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: '<%= shout("hello") %>')

      build_site
      assert_output_includes("index.html", "HELLO")
    end

    def test_multiple_helper_files
      FileUtils.mkdir_p(File.join(@src, "_helpers"))
      File.write(File.join(@src, "_helpers", "a.rb"), <<~RUBY)
        def greet(name)
          "hi " + name
        end
      RUBY
      File.write(File.join(@src, "_helpers", "b.rb"), <<~RUBY)
        def farewell(name)
          "bye " + name
        end
      RUBY
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: '<%= greet("world") %> <%= farewell("world") %>')

      build_site
      assert_output_includes("index.html", "hi world bye world")
    end

    def test_collections_sorted
      write_site_yml("collections:\n  posts:\n    sort_by: date\n    order: desc")
      write_layout("<%= page.content %>")
      write_page("posts/a.html", title: "First", date: "2024-01-01", body: "A")
      write_page("posts/b.html", title: "Second", date: "2024-06-01", body: "B")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %><%= p.title %>,<% end %>')

      build_site
      assert_output_includes("list/index.html", "Second,First,")
    end

    def test_collections_ascending_order
      write_site_yml("collections:\n  posts:\n    sort_by: date\n    order: asc")
      write_layout("<%= page.content %>")
      write_page("posts/a.html", title: "First", date: "2024-01-01", body: "A")
      write_page("posts/b.html", title: "Second", date: "2024-06-01", body: "B")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %><%= p.title %>,<% end %>')

      build_site
      assert_output_includes("list/index.html", "First,Second,")
    end

    def test_collections_sort_by_title
      write_site_yml("collections:\n  projects:\n    sort_by: title")
      write_layout("<%= page.content %>")
      write_page("projects/z.html", title: "Zebra", body: "Z")
      write_page("projects/a.html", title: "Alpha", body: "A")
      write_page("list.html", title: "List", body: '<% data.projects.each do |p| %><%= p.title %>,<% end %>')

      build_site
      assert_output_includes("list/index.html", "Alpha,Zebra,")
    end

    def test_collection_items_have_url
      write_site_yml("collections:\n  posts:\n    sort_by: date")
      write_layout("<%= page.content %>")
      write_page("posts/hello.html", title: "Hello", date: "2024-01-01", body: "Hi")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %><%= p.url %><% end %>')

      build_site
      assert_output_includes("list/index.html", "/posts/hello/")
    end

    def test_collection_items_bracket_access
      write_site_yml("collections:\n  posts:\n    sort_by: date")
      write_layout("<%= page.content %>")
      write_page("posts/hello.html", title: "Hello", date: "2024-01-01", body: "Hi")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %><%= p["title"] %><% end %>')

      build_site
      assert_output_includes("list/index.html", "Hello")
    end

    def test_env_defaults_to_development
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "<%= site.env %>")

      build_site
      assert_output_includes("index.html", "development")
    end

    def test_env_respects_purity_env
      ENV["PURITY_ENV"] = "staging"
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "<%= site.env %>")

      build_site
      assert_output_includes("index.html", "staging")
    ensure
      ENV.delete("PURITY_ENV")
    end

    def test_per_env_config
      write_site_yml("site_name: My Site\nenvironments:\n  development:\n    strict_variables: false\n  production:\n    strict_variables: true")
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "Hello")

      build_site
      assert_output_includes("index.html", "Hello")
    end

    def test_per_env_config_merges_into_site
      write_site_yml("site_name: My Site\nenvironments:\n  development:\n    debug: enabled")
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "<%= site.debug %>")

      build_site
      assert_output_includes("index.html", "enabled")
    end

    def test_environments_key_not_in_site_vars
      write_site_yml("site_name: My Site\nenvironments:\n  development:\n    debug: enabled")
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "env:<%= site.environments %>")

      build_site
      assert_output_includes("index.html", "env:")
    end

    def test_excerpt_on_all_pages
      write_layout("<%= page.content %>")
      write_page("about.html", title: "About", body: "First paragraph\n\nSecond paragraph")
      write_page("list.html", title: "List", body: '<% data.pages.each do |p| %>[<%= p.excerpt %>]<% end %>')

      build_site
      assert_output_includes("list/index.html", "[First paragraph]")
    end

    def test_excerpt_from_front_matter
      write_site_yml("collections:\n  posts:\n    sort_by: date")
      write_layout("<%= page.content %>")
      write_page("posts/post.html", title: "Post", date: "2024-01-01", excerpt: "Custom excerpt", body: "Full body here")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %><%= p.excerpt %><% end %>')

      build_site
      assert_output_includes("list/index.html", "Custom excerpt")
    end

    def test_excerpt_from_more_separator
      write_site_yml("collections:\n  posts:\n    sort_by: date")
      write_layout("<%= page.content %>")
      FileUtils.mkdir_p(File.join(@src, "posts"))
      File.write(File.join(@src, "posts", "post.html"), "---\ntitle: Post\ndate: 2024-01-01\n---\nFirst part\n<!-- more -->\nSecond part")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %>[<%= p.excerpt %>]<% end %>')

      build_site
      assert_output_includes("list/index.html", "[First part]")
    end

    def test_excerpt_first_paragraph
      write_site_yml("collections:\n  posts:\n    sort_by: date")
      write_layout("<%= page.content %>")
      FileUtils.mkdir_p(File.join(@src, "posts"))
      File.write(File.join(@src, "posts", "post.html"), "---\ntitle: Post\ndate: 2024-01-01\n---\nFirst paragraph\n\nSecond paragraph")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %>[<%= p.excerpt %>]<% end %>')

      build_site
      assert_output_includes("list/index.html", "[First paragraph]")
    end

    def test_excerpt_front_matter_overrides_auto
      write_site_yml("collections:\n  posts:\n    sort_by: date")
      write_layout("<%= page.content %>")
      FileUtils.mkdir_p(File.join(@src, "posts"))
      File.write(File.join(@src, "posts", "post.html"), "---\ntitle: Post\ndate: 2024-01-01\nexcerpt: Manual\n---\nFirst part\n<!-- more -->\nSecond part")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %>[<%= p.excerpt %>]<% end %>')

      build_site
      assert_output_includes("list/index.html", "[Manual]")
    end

    def test_clean_urls_transforms_html_to_directory
      write_layout("<%= page.content %>")
      write_page("about.html", title: "About", body: "About page")

      build_site
      assert(File.exist?(File.join(@dest, "about", "index.html")))
    end

    def test_clean_urls_preserves_root_index
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Home", body: "Home page")

      build_site
      assert(File.exist?(File.join(@dest, "index.html")))
      refute(File.exist?(File.join(@dest, "index", "index.html")))
    end

    def test_clean_urls_preserves_subdirectory_index
      write_layout("<%= page.content %>")
      FileUtils.mkdir_p(File.join(@src, "blog"))
      File.write(File.join(@src, "blog", "index.html"), "---\ntitle: Blog\n---\nBlog index")

      build_site
      assert(File.exist?(File.join(@dest, "blog", "index.html")))
    end

    def test_clean_urls_disabled_via_config
      write_site_yml("clean_urls: false")
      write_layout("<%= page.content %>")
      write_page("about.html", title: "About", body: "About page")

      build_site
      assert(File.exist?(File.join(@dest, "about.html")))
      refute(File.exist?(File.join(@dest, "about", "index.html")))
    end

    def test_clean_urls_does_not_affect_permalink
      write_layout("<%= page.content %>")
      write_page("post.html", title: "Post", permalink: "/blog/my-post/", body: "Content")

      build_site
      assert(File.exist?(File.join(@dest, "blog", "my-post", "index.html")))
    end

    def test_clean_urls_preserves_error_pages
      write_layout("<%= page.content %>")
      write_page("404.html", title: "Not Found", body: "Page not found")

      build_site
      assert(File.exist?(File.join(@dest, "404.html")))
      refute(File.exist?(File.join(@dest, "404", "index.html")))
    end

    def test_clean_urls_sitemap_has_clean_paths
      write_site_yml("url: https://example.com")
      write_layout("<%= page.content %>")
      write_page("about.html", title: "About", body: "About")
      write_page("index.html", title: "Home", body: "Home")

      build_site
      sitemap = read_output("sitemap.xml")
      assert_includes(sitemap, "https://example.com/about/")
      assert_includes(sitemap, "https://example.com/")
    end

    def test_page_url_in_template
      write_layout("<%= page.content %>")
      write_page("about.html", title: "About", body: "<%= page.url %>")

      build_site
      assert_output_includes("about/index.html", "/about/")
    end

    def test_page_url_for_index
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Home", body: "<%= page.url %>")

      build_site
      assert_output_includes("index.html", "/")
    end

    def test_page_url_with_permalink
      write_layout("<%= page.content %>")
      write_page("post.html", title: "Post", permalink: "/blog/my-post/", body: "<%= page.url %>")

      build_site
      assert_output_includes("blog/my-post/index.html", "/blog/my-post/")
    end

    def test_page_url_in_layout
      write_layout("path:<%= page.url %>|<%= page.content %>")
      write_page("about.html", title: "About", body: "Hello")

      build_site
      assert_output_includes("about/index.html", "path:/about/|")
    end

    def test_data_pages_collection_available
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Home", body: '<% data.pages.each do |p| %><%= p.title %>,<% end %>')
      write_page("about.html", title: "About", body: "About")

      build_site
      output = read_output("index.html")
      assert_includes(output, "Home,")
      assert_includes(output, "About,")
    end

    def test_data_pages_excludes_standalone
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Home", body: '<% data.pages.each do |p| %><%= p.title %>,<% end %>')
      write_page("raw.html", layout: false, body: "standalone")

      build_site
      output = read_output("index.html")
      assert_includes(output, "Home,")
      refute_includes(output, "standalone")
    end

    def test_data_pages_have_url
      write_layout("<%= page.content %>")
      write_page("about.html", title: "About", body: "About")
      write_page("index.html", title: "Home", body: '<% data.pages.each do |p| %><%= p.url %>;<% end %>')

      build_site
      output = read_output("index.html")
      assert_includes(output, "/about/;")
      assert_includes(output, "/;")
    end

    def test_data_pages_excludes_drafts
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Home", body: '<% data.pages.each do |p| %><%= p.title %>,<% end %>')
      write_page("secret.html", title: "Secret", draft: true, body: "Secret")

      build_site
      output = read_output("index.html")
      refute_includes(output, "Secret,")
    end

    def test_404_page_builds_without_clean_urls_mangling
      write_layout("<%= page.content %>")
      write_page("404.html", title: "Not Found", body: "Page not found")

      build_site
      assert(File.exist?(File.join(@dest, "404.html")))
      refute(File.exist?(File.join(@dest, "404", "index.html")))
    end

    def test_feed_uses_all_dated_pages
      write_site_yml("url: https://example.com\nsite_name: Test\ncollections:\n  posts:\n    sort_by: date\n    order: desc\n  projects:\n    sort_by: date\n    order: desc")
      write_layout("<%= page.content %>")
      write_page("posts/a.html", title: "Post A", date: "2024-01-01", body: "A")
      write_page("projects/b.html", title: "Project B", date: "2024-06-01", body: "B")

      build_site
      feed = read_output("feed.xml")
      assert_includes(feed, "Post A")
      assert_includes(feed, "Project B")
    end

    def test_strict_mode_from_site_yml
      write_site_yml("strict_variables: true")
      write_layout("<%= page.content %>")
      write_page("index.html", title: "Hi", body: "<%= page.title %>")

      build_site
      assert_output_includes("index.html", "Hi")
    end

    def test_multiple_collections
      write_site_yml("collections:\n  posts:\n    sort_by: date\n    order: desc\n  projects:\n    sort_by: title")
      write_layout("<%= page.content %>")
      write_page("posts/a.html", title: "Post A", date: "2024-01-01", body: "PA")
      write_page("projects/z.html", title: "Zebra", body: "Z")
      write_page("projects/a.html", title: "Alpha", body: "A")
      write_page("list.html", title: "List", body: '<% data.posts.each do |p| %><%= p.title %>,<% end %>|<% data.projects.each do |p| %><%= p.title %>,<% end %>')

      build_site
      assert_output_includes("list/index.html", "Post A,|Alpha,Zebra,")
    end

    def test_page_content_in_layout
      write_layout("[<%= page.content %>]")
      write_page("index.html", title: "Hi", body: "body text")

      build_site
      assert_output_includes("index.html", "[body text]")
    end

    private

    def write_markdown_plugin
      FileUtils.mkdir_p(File.join(@src, "_plugins"))
      File.write(File.join(@src, "_plugins", "markdown.rb"), <<~RUBY)
        hook(:before_layout) do |content, meta, context|
          next content unless meta["format"] == "md"
          content
            .gsub(/^# (.+)$/, '<h1>\\1</h1>')
            .gsub(/\\*\\*(.+?)\\*\\*/, '<strong>\\1</strong>')
        end
      RUBY
    end

    def write_layout(content)
      File.write(File.join(@src, "_layout.html"), content)
    end

    def write_site_yml(content)
      File.write(File.join(@src, "_site.yml"), content)
    end

    def write_file(name, content)
      File.write(File.join(@src, name), content)
    end

    def write_page(name, body:, **meta)
      fm = meta.map { |k, v| "#{k}: #{v}" }.join("\n")
      full_path = File.join(@src, name)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, "---\n#{fm}\n---\n#{body}")
    end

    def build_site(include_drafts: false)
      site = Purity::Site.new(src: @src, dest: @dest)
      capture_io { site.build(include_drafts: include_drafts) }
    end

    def read_output(name)
      File.read(File.join(@dest, name))
    end

    def assert_output_includes(name, expected)
      assert_includes(read_output(name), expected)
    end

    def refute_output_includes(name, expected)
      refute_includes(read_output(name), expected)
    end
  end
end
