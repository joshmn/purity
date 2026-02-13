# frozen_string_literal: true

require "test_helper"

module Purity
  class ScaffoldTest < Minitest::Test
    def setup
      @tmpdir = Dir.mktmpdir
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    def test_creates_site_structure
      dir = File.join(@tmpdir, "mysite")
      Scaffold.new(dir).run

      assert(File.exist?(File.join(dir, "Gemfile")))
      assert(Dir.exist?(File.join(dir, "src")))
      assert(Dir.exist?(File.join(dir, "src", "_plugins")))
      assert(Dir.exist?(File.join(dir, "src", "_helpers")))
      assert(File.exist?(File.join(dir, "src", "_site.yml")))
      assert(File.exist?(File.join(dir, "src", "_layout.html")))
      assert(File.exist?(File.join(dir, "src", "index.html")))
    end

    def test_layout_is_valid_html
      dir = File.join(@tmpdir, "mysite")
      Scaffold.new(dir).run

      layout = File.read(File.join(dir, "src", "_layout.html"))
      assert_includes(layout, "<!doctype html>")
      assert_includes(layout, "<%= page.content %>")
      assert_includes(layout, "<%= page.title %>")
    end

    def test_index_has_front_matter
      dir = File.join(@tmpdir, "mysite")
      Scaffold.new(dir).run

      index = File.read(File.join(dir, "src", "index.html"))
      assert(index.start_with?("---\n"))
      assert_includes(index, "title:")
    end

    def test_site_config_has_site_name
      dir = File.join(@tmpdir, "mysite")
      Scaffold.new(dir).run

      config = YAML.safe_load(File.read(File.join(dir, "src", "_site.yml")))
      assert(config["site_name"])
    end

    def test_refuses_nonempty_directory
      dir = File.join(@tmpdir, "mysite")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "existing.txt"), "hello")

      result = capture_io { Scaffold.new(dir).run }
      assert_includes(result[0], "already exists and is not empty")
      refute(File.exist?(File.join(dir, "src")))
    end

    def test_scaffolded_site_builds
      dir = File.join(@tmpdir, "mysite")
      Scaffold.new(dir).run

      site = Site.new(src: File.join(dir, "src"), dest: File.join(dir, "build"))
      site.build

      assert(File.exist?(File.join(dir, "build", "index.html")))
      html = File.read(File.join(dir, "build", "index.html"))
      assert_includes(html, "<h1>home</h1>")
    end
  end
end
