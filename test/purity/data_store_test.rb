# frozen_string_literal: true

require "test_helper"

module Purity
  class DataStoreTest < Minitest::Test
    def setup
      @dir = Dir.mktmpdir
      @data_dir = File.join(@dir, "_data")
      FileUtils.mkdir_p(@data_dir)
    end

    def teardown
      FileUtils.rm_rf(@dir)
    end

    def test_loads_yaml_file
      File.write(File.join(@data_dir, "nav.yml"), "- label: Home\n  url: /")
      store = DataStore.new(@data_dir)
      result = store["nav"]
      assert_equal("Home", result.first["label"])
      assert_equal("/", result.first["url"])
    end

    def test_loads_yaml_extension
      File.write(File.join(@data_dir, "nav.yaml"), "- label: Home")
      store = DataStore.new(@data_dir)
      result = store["nav"]
      assert_equal("Home", result.first["label"])
    end

    def test_loads_json_file
      File.write(File.join(@data_dir, "social.json"), '{"github": "joshmn"}')
      store = DataStore.new(@data_dir)
      assert_equal("joshmn", store["social"]["github"])
    end

    def test_nested_directory_uses_dot_key
      FileUtils.mkdir_p(File.join(@data_dir, "i18n"))
      File.write(File.join(@data_dir, "i18n", "en.yml"), "hello: Hi")
      store = DataStore.new(@data_dir)
      assert_equal("Hi", store["i18n.en"]["hello"])
    end

    def test_missing_key_returns_nil
      store = DataStore.new(@data_dir)
      assert_nil(store["nope"])
    end

    def test_missing_data_dir_returns_nil
      store = DataStore.new(File.join(@dir, "nonexistent"))
      assert_nil(store["anything"])
    end

    def test_empty_when_no_dir
      store = DataStore.new(File.join(@dir, "nonexistent"))
      assert(store.empty?)
    end

    def test_empty_when_no_files
      store = DataStore.new(@data_dir)
      assert(store.empty?)
    end

    def test_not_empty_with_files
      File.write(File.join(@data_dir, "nav.yml"), "- Home")
      store = DataStore.new(@data_dir)
      refute(store.empty?)
    end

    def test_caches_after_first_access
      File.write(File.join(@data_dir, "nav.yml"), "- Home")
      store = DataStore.new(@data_dir)
      first = store["nav"]
      File.write(File.join(@data_dir, "nav.yml"), "- Changed")
      assert_equal(first, store["nav"])
    end

    def test_key_check
      File.write(File.join(@data_dir, "nav.yml"), "- Home")
      store = DataStore.new(@data_dir)
      assert(store.key?("nav"))
      refute(store.key?("nope"))
    end

    def test_yaml_with_dates
      File.write(File.join(@data_dir, "events.yml"), "- name: Launch\n  date: 2024-01-01")
      store = DataStore.new(@data_dir)
      assert_equal(Date.new(2024, 1, 1), store["events"].first["date"])
    end

    def test_dot_access
      File.write(File.join(@data_dir, "nav.yml"), "- label: Home")
      store = DataStore.new(@data_dir)
      assert_equal("Home", store.nav.first.label)
    end

    def test_bracket_assignment
      store = DataStore.new(@data_dir)
      store["items"] = [{ "name" => "a" }]
      assert_equal("a", store["items"].first["name"])
    end

    def test_strict_mode_raises_on_missing
      store = DataStore.new(@data_dir, strict: true)
      assert_raises(UndefinedVariableError) { store.nope }
    end

    def test_non_strict_mode_returns_nil
      store = DataStore.new(@data_dir)
      assert_nil(store.nope)
    end
  end
end
