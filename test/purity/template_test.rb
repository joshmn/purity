# frozen_string_literal: true

require "test_helper"

module Purity
  class TemplateTest < Minitest::Test
    class Renderer
      include Template

      attr_reader :src, :helpers_module

      def initialize(src:)
        @src = src
        @hooks = Hash.new { |h, k| h[k] = [] }
        @helpers_module = Module.new
      end

      def hook(name, &block)
        @hooks[name] << block
      end

      def parse(path)
        raw = File.read(path)
        return [{}, raw] unless raw.start_with?("---\n")

        parts = raw.split("---\n", 3)
        [YAML.safe_load(parts[1]) || {}, parts[2] || ""]
      end
    end

    def setup
      @dir = Dir.mktmpdir
      @renderer = Renderer.new(src: @dir)
    end

    def teardown
      FileUtils.rm_rf(@dir)
    end

    def test_substitutes_variables
      result = @renderer.render(body: "Hello <%= page.name %>", context: { page: { "name" => "World" } })
      assert_equal("Hello World", result)
    end

    def test_undefined_variable_renders_empty
      result = @renderer.render(body: "Hello <%= page.name %>", context: { page: {} })
      assert_equal("Hello ", result)
    end

    def test_if_true
      result = @renderer.render(body: "<% if page.show %>yes<% end %>", context: { page: { "show" => true } })
      assert_equal("yes", result)
    end

    def test_if_false
      result = @renderer.render(body: "<% if page.show %>yes<% end %>", context: { page: { "show" => false } })
      assert_equal("", result)
    end

    def test_if_missing_key
      result = @renderer.render(body: "<% if page.show %>yes<% end %>", context: { page: {} })
      assert_equal("", result)
    end

    def test_if_with_value_match
      result = @renderer.render(body: '<% if page.color == "red" %>match<% end %>', context: { page: { "color" => "red" } })
      assert_equal("match", result)
    end

    def test_if_with_value_mismatch
      result = @renderer.render(body: '<% if page.color == "red" %>match<% end %>', context: { page: { "color" => "blue" } })
      assert_equal("", result)
    end

    def test_if_else_true_branch
      result = @renderer.render(body: "<% if page.show %>yes<% else %>no<% end %>", context: { page: { "show" => true } })
      assert_equal("yes", result)
    end

    def test_if_else_false_branch
      result = @renderer.render(body: "<% if page.show %>yes<% else %>no<% end %>", context: { page: {} })
      assert_equal("no", result)
    end

    def test_unless_renders_when_falsy
      result = @renderer.render(body: "<% unless page.hide %>visible<% end %>", context: { page: {} })
      assert_equal("visible", result)
    end

    def test_unless_hides_when_truthy
      result = @renderer.render(body: "<% unless page.hide %>visible<% end %>", context: { page: { "hide" => true } })
      assert_equal("", result)
    end

    def test_each_loop
      items = [{ "name" => "a" }, { "name" => "b" }]
      result = @renderer.render(body: '<% page.items.each do |item| %><%= item.name %>,<% end %>', context: { page: { "items" => items } })
      assert_equal("a,b,", result)
    end

    def test_each_with_bracket_access
      items = [{ "name" => "a" }, { "name" => "b" }]
      result = @renderer.render(body: '<% page.items.each do |item| %><%= item["name"] %>,<% end %>', context: { page: { "items" => items } })
      assert_equal("a,b,", result)
    end

    def test_each_with_non_hash_items
      result = @renderer.render(body: "<% page.items.each do |item| %><%= item %>,<% end %>", context: { page: { "items" => ["x", "y"] } })
      assert_equal("x,y,", result)
    end

    def test_each_with_missing_key
      result = @renderer.render(body: "<% (page.missing || []).each do |item| %>nope<% end %>", context: { page: {} })
      assert_equal("", result)
    end

    def test_partial_inclusion
      File.write(File.join(@dir, "_header.html"), "<h1>Hello</h1>")
      result = @renderer.render(body: '<%= partial "_header.html" %>', context: { page: {} })
      assert_equal("<h1>Hello</h1>", result)
    end

    def test_partial_with_args
      File.write(File.join(@dir, "_greet.html"), "Hello <%= page.who %>")
      result = @renderer.render(body: '<%= partial "_greet.html", who: "World" %>', context: { page: {} })
      assert_equal("Hello World", result)
    end

    def test_partial_args_dont_leak
      File.write(File.join(@dir, "_inner.html"), "<%= page.local %>")
      result = @renderer.render(body: '<%= partial "_inner.html", local: "scoped" %> <%= page.local %>', context: { page: {} })
      assert_equal("scoped ", result)
    end

    def test_partial_missing_file
      result = @renderer.render(body: '<%= partial "_nope.html" %>', context: { page: {} })
      assert_equal("", result)
    end

    def test_full_pipeline
      File.write(File.join(@dir, "_nav.html"), '<% if page.active == "home" %>HOME<% end %>')
      result = @renderer.render(body: '<%= partial "_nav.html" %> - <%= page.title %>', context: { page: { "active" => "home", "title" => "Test" } })
      assert_equal("HOME - Test", result)
    end

    def test_boolean_true_is_truthy
      result = @renderer.render(body: "<% if page.flag %>yes<% end %>", context: { page: { "flag" => true } })
      assert_equal("yes", result)
    end

    def test_boolean_false_is_falsy
      result = @renderer.render(body: "<% if page.flag %>yes<% end %>", context: { page: { "flag" => false } })
      assert_equal("", result)
    end

    def test_nil_is_falsy
      result = @renderer.render(body: "<% if page.flag %>yes<% end %>", context: { page: { "flag" => nil } })
      assert_equal("", result)
    end

    def test_content_for_and_yield
      File.write(File.join(@dir, "_layout.html"), "<head><%= content_for :head %></head><body><%= page.content %></body>")
      body = "<% content_for :head do %><style>h1{}</style><% end %>Hello"
      result = @renderer.render_page(meta: {}, body: body, context: { page: {} })
      assert_includes(result, "<head><style>h1{}</style></head>")
      assert_includes(result, "Hello")
    end

    def test_multiple_content_for_blocks
      File.write(File.join(@dir, "_layout.html"), "<head><%= content_for :head %></head><body><%= page.content %><%= content_for :scripts %></body>")
      body = "<% content_for :head do %><style>h1{}</style><% end %><% content_for :scripts do %><script>1</script><% end %>Hello"
      result = @renderer.render_page(meta: {}, body: body, context: { page: {} })
      assert_includes(result, "<head><style>h1{}</style></head>")
      assert_includes(result, "<script>1</script>")
      assert_includes(result, "Hello")
    end

    def test_content_for_without_block_returns_empty
      File.write(File.join(@dir, "_layout.html"), "<head><%= content_for :head %></head><body><%= page.content %></body>")
      result = @renderer.render_page(meta: {}, body: "Hello", context: { page: {} })
      assert_includes(result, "<head></head>")
    end

    def test_content_for_predicate
      File.write(File.join(@dir, "_layout.html"), '<% if content_for?(:head) %>has head<% end %><%= page.content %>')
      body = "<% content_for :head do %>stuff<% end %>Hello"
      result = @renderer.render_page(meta: {}, body: body, context: { page: {} })
      assert_includes(result, "has head")
    end

    def test_render_page_standalone
      result = @renderer.render_page(meta: { "layout" => false }, body: "<p>Raw</p>", context: { page: {} })
      assert_equal("<p>Raw</p>", result)
    end

    def test_nested_each_loops
      ctx = {
        page: {
          "groups" => [
            { "label" => "A", "items" => [{ "name" => "a1" }, { "name" => "a2" }] },
            { "label" => "B", "items" => [{ "name" => "b1" }] }
          ]
        }
      }
      template = '<% page.groups.each do |g| %><%= g.label %>:<% g.items.each do |i| %><%= i.name %>,<% end %>;<% end %>'
      result = @renderer.render(body: template, context: ctx)
      assert_equal("A:a1,a2,;B:b1,;", result)
    end

    def test_nested_if_blocks
      ctx = { page: { "a" => true, "b" => true } }
      result = @renderer.render(body: "<% if page.a %><% if page.b %>both<% end %><% end %>", context: ctx)
      assert_equal("both", result)
    end

    def test_nested_if_outer_false
      ctx = { page: { "a" => false, "b" => true } }
      result = @renderer.render(body: "<% if page.a %><% if page.b %>both<% end %><% end %>", context: ctx)
      assert_equal("", result)
    end

    def test_nested_if_with_else
      ctx = { page: { "a" => true, "b" => false } }
      result = @renderer.render(body: "<% if page.a %><% if page.b %>yes<% else %>no<% end %><% end %>", context: ctx)
      assert_equal("no", result)
    end

    def test_nested_unless
      result = @renderer.render(body: "<% unless page.a %><% unless page.b %>both<% end %><% end %>", context: { page: {} })
      assert_equal("both", result)
    end

    def test_if_inside_each
      items = [{ "name" => "a", "active" => true }, { "name" => "b", "active" => false }]
      template = '<% page.items.each do |item| %><% if item.active %><%= item.name %><% end %><% end %>'
      result = @renderer.render(body: template, context: { page: { "items" => items } })
      assert_equal("a", result)
    end

    def test_before_layout_transforms_content
      File.write(File.join(@dir, "_layout.html"), "<body><%= page.content %></body>")
      @renderer.hook(:before_layout) { |content, _meta, _ctx| content.upcase }
      result = @renderer.render_page(meta: {}, body: "hello", context: { page: {} })
      assert_includes(result, "<body>HELLO</body>")
    end

    def test_before_layout_skips_standalone
      @renderer.hook(:before_layout) { |content, _meta, _ctx| content.upcase }
      result = @renderer.render_page(meta: { "layout" => false }, body: "hello", context: { page: {} })
      assert_equal("hello", result)
    end

    def test_before_layout_chains_multiple_hooks
      File.write(File.join(@dir, "_layout.html"), "<%= page.content %>")
      @renderer.hook(:before_layout) { |content, _meta, _ctx| content + " first" }
      @renderer.hook(:before_layout) { |content, _meta, _ctx| content + " second" }
      result = @renderer.render_page(meta: {}, body: "start", context: { page: {} })
      assert_equal("start first second", result)
    end

    def test_before_layout_receives_meta
      File.write(File.join(@dir, "_layout.html"), "<%= page.content %>")
      received_meta = nil
      @renderer.hook(:before_layout) { |content, meta, _ctx| received_meta = meta; content }
      @renderer.render_page(meta: { "title" => "Test" }, body: "hello", context: { page: {} })
      assert_equal("Test", received_meta["title"])
    end

    def test_site_variable_accessible
      result = @renderer.render(body: "<%= site.name %>", context: { site: { "name" => "My Site" }, page: {} })
      assert_equal("My Site", result)
    end

    def test_site_bracket_access
      result = @renderer.render(body: '<%= site["name"] %>', context: { site: { "name" => "My Site" }, page: {} })
      assert_equal("My Site", result)
    end

    def test_page_bracket_access
      result = @renderer.render(body: '<%= page["title"] %>', context: { page: { "title" => "Hello" } })
      assert_equal("Hello", result)
    end

    def test_strict_mode_raises_on_undefined_page_var
      ctx = { site: { "strict_variables" => true }, page: {} }
      assert_raises(UndefinedVariableError) do
        @renderer.render(body: "<%= page.missing %>", context: ctx)
      end
    end

    def test_strict_mode_off_returns_nil
      ctx = { site: { "strict_variables" => false }, page: {} }
      result = @renderer.render(body: "Hello<%= page.missing %>", context: ctx)
      assert_equal("Hello", result)
    end

    def test_strict_mode_raises_on_undefined_bare_var
      ctx = { site: { "strict_variables" => true }, page: {} }
      assert_raises(UndefinedVariableError) do
        @renderer.render(body: "<%= something %>", context: ctx)
      end
    end
  end
end
