# frozen_string_literal: true

require "test_helper"

module Oxc
  class ErrorsTest < Minitest::Spec
    test "refuses an option it does not know" do
      error = assert_raises(OptionError) { Oxc.minify("foo()", nonsense: true) }

      assert_equal "Unknown option: nonsense", error.message
    end

    test "names the option it does not know inside a nested one, and what it could have been" do
      error = assert_raises(OptionError) { Oxc.minify("foo()", compress: { nonsense: true }) }

      assert_equal "Invalid options: unknown field `nonsense`, expected one of `target`, `drop_console`, `drop_debugger`, `unused`, `keep_names`, `join_vars`, `sequences`, `drop_labels`, `max_iterations`, `treeshake` at line 1 column 23", error.message
    end

    test "says what a nested option should have been given" do
      error = assert_raises(OptionError) { Oxc.minify("foo()", compress: "yes") }

      assert_equal "Invalid options: invalid type: string \"yes\", expected true, false, or a hash of settings at line 1 column 17", error.message
    end

    test "refuses a target it cannot read" do
      error = assert_raises(OptionError) { Oxc.minify("foo()", compress: { target: "es1066" }) }

      assert_equal "Invalid target 'es1066'.", error.message
    end

    test "refuses a lang it cannot read" do
      error = assert_raises(OptionError) { Oxc.minify("foo()", lang: "ruby") }

      assert_equal "Unknown lang: ruby. Expected js, jsx, ts, tsx or dts.", error.message
    end

    test "refuses a source type it cannot read" do
      error = assert_raises(OptionError) { Oxc.minify("foo()", source_type: "nonsense") }

      assert_equal "Unknown source_type: nonsense. Expected script, module, commonjs or unambiguous.", error.message
    end

    test "refuses a legal comments mode it cannot read" do
      error = assert_raises(OptionError) { Oxc.minify("foo()", codegen: { legal_comments: "nope" }) }

      assert_equal "Unknown legal_comments: nope. Expected none, inline, eof, external or a linked path.", error.message
    end

    test "raises when it could not read the source at all" do
      error = assert_raises(SyntaxError) { Oxc.minify("const x = ;") }

      assert_equal "Unexpected token", error.message
    end

    test "carries the diagnostics and the result it was raised from" do
      error = assert_raises(SyntaxError) { Oxc.minify("const x = ;", filename: "broken.js") }

      assert_equal 1, error.diagnostics.length
      assert_predicate error.result, :panicked?
      assert_equal "", error.result.code
    end

    test "a syntax error is rescued by a bare rescue, unlike Ruby's own" do
      rescued = begin
        Oxc.minify("const x = ;")
      rescue StandardError => e
        e
      end

      assert_kind_of Oxc::SyntaxError, rescued
      refute_kind_of ::SyntaxError, rescued
    end

    test "refuses source that is not UTF-8" do
      error = assert_raises(EncodingError) { Oxc.minify([0xff, 0xfe].pack("C*")) }

      assert_equal "Invalid UTF-8 in source: invalid utf-8 sequence of 1 bytes from index 0", error.message
    end

    test "every error it raises is an error" do
      assert_operator Oxc::OptionError, :<, Oxc::Error
      assert_operator Oxc::EncodingError, :<, Oxc::Error
      assert_operator Oxc::TransformError, :<, Oxc::Error
      assert_operator Oxc::InternalError, :<, Oxc::Error
      assert_operator Oxc::PanicError, :<, Oxc::InternalError
      assert_operator Oxc::SyntaxError, :<, Oxc::Error
      assert_operator Oxc::Error, :<, StandardError
    end
  end
end
