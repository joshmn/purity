# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(__dir__, "lib"))
require "purity/version"

Gem::Specification.new do |s|
  s.name = "purity"
  s.version = Purity::VERSION
  s.summary = "a simple static site generator"
  s.description = "templates, partials, conditionals, loops, layouts, blog, plugins. nothing else."
  s.authors = ["Josh Brody"]
  s.email = "josh@josh.mn"
  s.homepage = "https://github.com/joshmn/purity"
  s.license = "MIT"
  s.required_ruby_version = ">= 2.7"
  s.files = Dir["lib/**/*.rb", "exe/*"]
  s.bindir = "exe"
  s.executables = ["purity"]
  s.add_dependency "webrick"
end
