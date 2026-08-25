# frozen_string_literal: true

require "test_helper"

module Oxc
  class ScopeTest < Minitest::Spec
    SOURCE = <<~JS
      let count = 0
      const label = "Send"
      function bump() { const step = 1; count += step; render(label) }
      bump()
    JS

    SCOPED = %(let count_1a2b3c4d = 0;\nconst label_1a2b3c4d = "Send";\nfunction bump_1a2b3c4d() {\n\tconst step = 1;\n\tcount_1a2b3c4d += step;\n\trender(label_1a2b3c4d);\n}\nbump_1a2b3c4d();\n)

    test "renames what the file declared at the top level, and every reference to it" do
      assert_equal SCOPED, Oxc.scope(SOURCE, scope: "1a2b3c4d").code
    end

    test "leaves a name declared inside a scope of its own alone, and one the file never declared" do
      code = Oxc.scope(SOURCE, scope: "1a2b3c4d").code

      assert_equal "\tconst step = 1;\n", code.lines[3]
      assert_equal "\trender(label_1a2b3c4d);\n", code.lines[5]
    end

    test "says what each name became" do
      renamed = Oxc.scope(SOURCE, scope: "1a2b3c4d").renamed

      assert_equal({ "bump" => "bump_1a2b3c4d", "count" => "count_1a2b3c4d", "label" => "label_1a2b3c4d" }, renamed)
    end

    test "reads a separator of its own" do
      code = Oxc.scope("let a = 1; foo(a)", scope: "x", separator: "$").code

      assert_equal "let a$x = 1;\nfoo(a$x);\n", code
    end

    test "refuses a scope that could not read as part of a name" do
      error = assert_raises(OptionError) { Oxc.scope("let a = 1", scope: "1a-2b") }

      assert_equal 'Invalid scope "1a-2b". It has to read as part of a JavaScript name, so letters, digits, _ and $ only.',
                   error.message
    end

    test "refuses no scope at all" do
      error = assert_raises(OptionError) { Oxc.scope("let a = 1", scope: "") }

      assert_equal "scope has to be given, and has to read as part of a JavaScript name.", error.message
    end

    test "answers what it could not read instead of renaming it" do
      error = assert_raises(SyntaxError) { Oxc.scope("const x = ;", scope: "x") }

      assert_equal "Unexpected token", error.message
    end

    test "is a result of its own" do
      result = Oxc.scope("let a = 1; foo(a)", scope: "x")

      assert_kind_of Oxc::Result, result
      assert_instance_of Oxc::ScopeResult, result
      assert_predicate result, :frozen?
    end
  end
end
