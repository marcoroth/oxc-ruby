# frozen_string_literal: true

require "test_helper"

module Oxc
  class TransformResultTest < Minitest::Spec
    def declared
      source = "export const add = (a: number, b: number): number => a + b"

      Oxc.transform(source, filename: "add.ts", source_type: "module", typescript: { declaration: true })
    end

    test "is what transform answers" do
      result = Oxc.transform("foo()")

      assert_kind_of Oxc::Result, result
      assert_instance_of Oxc::TransformResult, result
    end

    test "carries what only a transform can answer" do
      assert_equal "export declare const add: (a: number, b: number) => number;\n", declared.declaration
      assert_empty declared.helpers_used
    end

    test "keeps what it answered to itself" do
      result = Oxc.transform("foo()")

      assert_predicate result, :frozen?
      assert_predicate result.helpers_used, :frozen?
      assert_predicate result.diagnostics, :frozen?
    end

    test "prints what it is" do
      assert_equal %(#<Oxc::TransformResult code="foo();\\n">), Oxc.transform("foo()").inspect
    end

    test "names the declaration it carries" do
      assert_equal %(#<Oxc::TransformResult code="export const add = (a, b) => a + b;\\n" declaration=60 bytes>), declared.inspect
    end

    test "names the helpers it reached for" do
      result = Oxc.transform("class A { x = 1 }; foo(A)", target: "es2015")

      assert_equal 1, result.helpers_used.length
      assert_equal %(#<Oxc::TransformResult code=#{result.code.inspect} helpers_used=1>), result.inspect
    end
  end
end
