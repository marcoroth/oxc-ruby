# frozen_string_literal: true

require "test_helper"

module Oxc
  class MutationVisitorTest < Minitest::Spec
    class Renamer < MutationVisitor
      def visit_identifier(node)
        replace(node, "renamed") if node["name"] == "count"
      end
    end

    test "splices what it was told to replace" do
      assert_equal "let renamed = 1", Renamer.new.rewrite("let count = 1")
    end

    test "leaves everything it did not touch byte for byte" do
      source = "let count = 1 // a comment\n\n  foo(count)   // another\n"
      rewritten = Renamer.new.rewrite(source)

      assert_equal "let renamed = 1 // a comment\n\n  foo(renamed)   // another\n", rewritten
    end

    test "removes a node, and only what the node covered" do
      remover = Class.new(MutationVisitor) do
        def visit_debugger_statement(node) = remove(node)
      end.new

      assert_equal "\nfoo();\n", remover.rewrite("debugger;\nfoo();\n")
    end

    test "inserts before and after" do
      wrapper = Class.new(MutationVisitor) do
        def visit_call_expression(node) = wrap(node, "await (", ")")
      end.new

      assert_equal "await (foo())", wrapper.rewrite("foo()")
    end

    test "applies two inserts at the same point in the order they were made" do
      double = Class.new(MutationVisitor) do
        def visit_call_expression(node)
          insert_before(node, "a")
          insert_before(node, "b")
        end
      end.new

      assert_equal "abfoo()", double.rewrite("foo()")
    end

    test "does not walk into a node it replaced" do
      counter = Class.new(MutationVisitor) do
        attr_reader :identifiers

        def initialize
          @identifiers = 0

          super
        end

        def visit_variable_declaration(node) = replace(node, "gone;")

        def visit_identifier(_node) = @identifiers += 1
      end.new

      assert_equal "gone; foo(a)", counter.rewrite("let a = 1; foo(a)")

      assert_equal 2, counter.identifiers
    end

    test "refuses two edits over the same span" do
      conflict = Class.new(MutationVisitor) do
        def visit_call_expression(node)
          replace(node, "a")
          replace(node, "b")
        end
      end.new

      error = assert_raises(MutationVisitor::Overlap) { conflict.rewrite("foo()") }

      assert_equal "an edit at 0..5 overlaps one at 0..5", error.message
    end

    test "reaches what the source parsed to" do
      reader = Class.new(MutationVisitor) do
        attr_reader :names

        def rewrite(source) = super(source, symbols: true)

        def visit_program(node)
          @names = parsed.symbols.fetch("declared").map { |symbol| symbol["name"] }

          visit_children(node)
        end
      end.new

      reader.rewrite("let a = 1; function b() {}")

      assert_equal ["a", "b"], reader.names
    end

    test "reads the source a node covers" do
      slicer = Class.new(MutationVisitor) do
        def visit_call_expression(node) = replace(node, node.slice(source).upcase)
      end.new

      assert_equal "FOO(1)", slicer.rewrite("foo(1)")
    end

    test "answers the source unchanged when it touched nothing" do
      quiet = Class.new(MutationVisitor).new

      assert_equal "let a = 1\n", quiet.rewrite("let a = 1\n")
    end

    test "puts in whatever it was given, whatever the node was" do
      grower = Class.new(MutationVisitor) do
        def visit_debugger_statement(node) = replace(node, "log(1);\nlog(2);")
      end.new

      assert_equal "log(1);\nlog(2);", grower.rewrite("debugger;")
    end

    test "reads back what it rewrote, and refuses what stopped being JavaScript" do
      breaker = Class.new(MutationVisitor) do
        def visit_identifier(node) = replace(node, "!!!")
      end.new

      error = assert_raises(MutationVisitor::Invalid) { breaker.rewrite("foo(data)") }

      assert_equal "what was rewritten no longer reads as JavaScript: Unexpected token", error.message
    end

    test "reads nothing back when it was told not to" do
      breaker = Class.new(MutationVisitor) do
        def visit_identifier(node) = replace(node, "!!!")
      end.new

      assert_equal "!!!(!!!)", breaker.rewrite("foo(data)", verify: false)
    end

    test "refuses source it could not read" do
      assert_raises(SyntaxError) { Renamer.new.rewrite("const x = ;") }
    end
  end
end
