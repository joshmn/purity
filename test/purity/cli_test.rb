# frozen_string_literal: true

require "test_helper"

module Purity
  class CLITest < Minitest::Test
    def test_help_flag
      output = capture_io { CLI.run(["help"]) }[0]
      assert_includes(output, "purity #{VERSION}")
      assert_includes(output, "usage:")
    end

    def test_version_flag
      output = capture_io { CLI.run(["version"]) }[0]
      assert_includes(output, VERSION)
    end

    def test_dash_h
      output = capture_io { CLI.run(["-h"]) }[0]
      assert_includes(output, "usage:")
    end

    def test_dash_dash_help
      output = capture_io { CLI.run(["--help"]) }[0]
      assert_includes(output, "usage:")
    end
  end
end
