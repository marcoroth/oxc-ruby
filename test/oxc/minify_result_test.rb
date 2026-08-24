# frozen_string_literal: true

require "test_helper"

module Oxc
  class MinifyResultTest < Minitest::Spec
    test "prints as its code" do
      assert_equal "foo();", Oxc.minify("foo()").to_s
    end

    test "keeps what it answered to itself" do
      result = Oxc.minify("foo()")

      assert_predicate result, :frozen?
      assert_predicate result.diagnostics, :frozen?
      assert_predicate result.legal_comments, :frozen?
    end

    test "is what minify answers, and carries nothing transform-only" do
      result = Oxc.minify("foo()")

      assert_kind_of Oxc::Result, result
      assert_instance_of Oxc::MinifyResult, result
      refute_respond_to result, :helpers_used
      refute_respond_to result, :declaration
    end

    test "reports nothing to say about source it fully read" do
      result = Oxc.minify("foo()")

      refute_predicate result, :errors?
      refute_predicate result, :warnings?
      refute_predicate result, :panicked?

      assert_empty result.errors
      assert_empty result.warnings
    end

    test "prints what it is" do
      assert_equal %(#<Oxc::MinifyResult code="foo();">), Oxc.minify("foo()").inspect
    end

    test "names the map it carries" do
      inspected = Oxc.minify("foo()", filename: "app.js", sourcemap: true).inspect

      assert_equal %(#<Oxc::MinifyResult code="foo();" map=95 bytes>), inspected
    end
  end
end
