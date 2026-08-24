# frozen_string_literal: true

require "test_helper"

module Oxc
  class ParseTest < Minitest::Spec
    test "answers the program it read" do
      program = Oxc.parse("let a = 1; const b = 'x'").program

      assert_equal "Program", program["type"]
      assert_equal(["VariableDeclaration", "VariableDeclaration"], program["body"].map { |node| node["type"] })
    end

    test "answers a declaration with the name and the literal it was given" do
      declarator = Oxc.parse("let a = 1").program["body"].first["declarations"].first

      assert_equal "a", declarator["id"]["name"]
      assert_equal 1, declarator["init"]["value"]
      assert_equal "1", declarator["init"]["raw"]
    end

    test "says what kind of declaration it was" do
      assert_equal "let", Oxc.parse("let a = 1").program["body"].first["kind"]
      assert_equal "const", Oxc.parse("const a = 1").program["body"].first["kind"]
    end

    test "leaves the range off unless it was asked for" do
      refute Oxc.parse("a").program["body"].first.key?("range")
      assert_equal [0, 1], Oxc.parse("a", ranges: true).program["body"].first["range"]
    end

    test "includes the TypeScript properties for TypeScript" do
      identifier = Oxc.parse("const x: number = 1", lang: "ts").program["body"].first["declarations"].first["id"]

      assert_equal ["type", "decorators", "name", "optional", "typeAnnotation", "start", "end"], identifier.keys
    end

    test "leaves them out when it was asked for a JavaScript AST" do
      parsed = Oxc.parse("const x: number = 1", lang: "ts", ast_type: "js")
      identifier = parsed.program["body"].first["declarations"].first["id"]

      assert_equal ["type", "name", "start", "end"], identifier.keys
    end

    test "keeps the parentheses that were written" do
      assert_equal "ParenthesizedExpression", Oxc.parse("(a)").program["body"].first["expression"]["type"]
    end

    test "drops them when it was told to" do
      parsed = Oxc.parse("(a)", preserve_parens: false)

      assert_equal "Identifier", parsed.program["body"].first["expression"]["type"]
    end

    test "answers no program at all when it was only asked to read" do
      parsed = Oxc.parse("const x = ;", ast: false)

      assert_nil parsed.program
      assert_equal ["Unexpected token"], parsed.errors.map(&:message)
    end

    test "answers the comments it read" do
      comments = Oxc.parse("// hi\nfoo() /* there */").comments

      assert_equal([["Line", " hi"], ["Block", " there "]], comments.map { |comment| [comment.type, comment.value] })
      assert_predicate comments.first, :line?
      assert_predicate comments.last, :block?
    end

    test "reads a hashbang as the line comment it looks like" do
      assert_equal ["/usr/bin/env node"], Oxc.parse("#!/usr/bin/env node\nfoo()").comments.map(&:value)
    end

    test "answers no comments when it was told not to read them" do
      assert_empty Oxc.parse("// hi\nfoo()", comments: false).comments
    end

    test "says nothing about a name declared twice unless it was asked to" do
      assert_empty Oxc.parse("let a; let a;").errors
    end

    test "reports what only semantic analysis can see" do
      parsed = Oxc.parse("let a; let a;", semantic_errors: true)

      assert_equal ["Identifier `a` has already been declared"], parsed.errors.map(&:message)
    end

    test "answers what it could not read instead of raising" do
      parsed = Oxc.parse("const x = ;")

      assert_equal ["Unexpected token"], parsed.errors.map(&:message)
      assert_predicate parsed, :errors?
      assert_predicate parsed, :panicked?
    end

    test "raises on demand" do
      error = assert_raises(SyntaxError) { Oxc.parse("const x = ;").validate! }

      assert_equal "Unexpected token", error.message
    end

    test "answers itself when there was nothing to say" do
      parsed = Oxc.parse("foo()")

      assert_same parsed, parsed.validate!
      refute_predicate parsed, :errors?
      refute_predicate parsed, :warnings?
      refute_predicate parsed, :panicked?
    end

    test "keeps what it read to itself" do
      parsed = Oxc.parse("foo()")

      assert_predicate parsed, :frozen?
      assert_predicate parsed.comments, :frozen?
      assert_predicate parsed.diagnostics, :frozen?
    end

    test "prints what it read" do
      assert_equal "#<Oxc::ParseResult program=Program>", Oxc.parse("foo()").inspect
      assert_equal "#<Oxc::ParseResult>", Oxc.parse("foo()", ast: false).inspect
    end

    test "refuses an ast type it cannot read" do
      error = assert_raises(OptionError) { Oxc.parse("foo()", ast_type: "ruby") }

      assert_equal "Unknown ast_type: ruby. Expected js or ts.", error.message
    end

    test "refuses an option parse does not read" do
      error = assert_raises(OptionError) { Oxc.parse("foo()", minify: true) }

      assert_equal "minify is not an option for parse", error.message
    end
  end
end
