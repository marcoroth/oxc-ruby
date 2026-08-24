# frozen_string_literal: true

require "test_helper"

module Oxc
  class MinifierTest < Minitest::Spec
    test "minifies with the options it was built with" do
      code = Minifier.new(compress: { drop_console: true }).minify("console.log(1); foo()").code

      assert_equal "foo();", code
    end

    test "merges what a call gives it over what it was built with" do
      code = Minifier.new(compress: { drop_console: true }).minify("console.log(1); foo()", mangle: false).code

      assert_equal "foo();", code
    end

    test "lets a call override an option it was built with" do
      minifier = Minifier.new(codegen: { remove_whitespace: false })

      assert_equal "foo(1);\n", minifier.minify("const x = 1; foo(x)").code
      assert_equal "foo(1);", minifier.minify("const x = 1; foo(x)", codegen: { remove_whitespace: true }).code
    end

    test "answers call, so it can be handed to anything callable" do
      assert_equal "foo();", Minifier.new.call("foo()").to_s
    end

    test "builds another minifier from itself, leaving the first alone" do
      base = Minifier.new
      readable = base.with(codegen: { remove_whitespace: false })

      assert_equal "foo(1);\n", readable.minify("const x = 1; foo(x)").code
      assert_equal "foo(1);", base.minify("const x = 1; foo(x)").code
    end

    test "keeps its options to itself" do
      minifier = Minifier.new(sourcemap: true)

      assert_predicate minifier, :frozen?
      assert_predicate minifier.options, :frozen?
      assert_equal({ sourcemap: true }, minifier.options)
    end

    test "prints what it was built with" do
      assert_equal "#<Oxc::Minifier {sourcemap: true}>", Minifier.new(sourcemap: true).inspect
    end

    test "refuses an option it does not read, when it is called" do
      error = assert_raises(OptionError) { Minifier.new(target: "es2015").minify("foo()") }

      assert_equal "target is not an option for minify", error.message
    end
  end
end
