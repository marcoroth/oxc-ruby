# frozen_string_literal: true

require "test_helper"

module Oxc
  class VisitorTest < Minitest::Spec
    SOURCE = "let count = 0\nfunction bump() { count += 1 }"

    class Collector < Visitor
      attr_reader :seen #: Array[String]

      def initialize
        @seen = []

        super
      end

      def visit_variable_declaration(node)
        seen << "#{node.kind} #{node.declarations.first.id["name"]}"

        visit_children(node)
      end

      def visit_assignment_expression(node)
        seen << "#{node.left["name"]} #{node.operator}"

        visit_children(node)
      end
    end

    test "answers a node with the method named after its type" do
      collector = Collector.new
      collector.visit(Oxc.parse(SOURCE).root)

      assert_equal ["let count", "count +="], collector.seen
    end

    test "takes a parse result and walks from its program" do
      collector = Collector.new
      collector.visit(Oxc.parse(SOURCE))

      assert_equal ["let count", "count +="], collector.seen
    end

    test "answers a result with no AST without visiting anything" do
      collector = Collector.new
      collector.visit(Oxc.parse(SOURCE, ast: false))

      assert_empty collector.seen
    end

    test "walks through a node nothing answers" do
      counter = Class.new(Visitor) do
        attr_reader :identifiers

        def initialize
          @identifiers = 0

          super
        end

        def visit_identifier(_node)
          @identifiers += 1
        end
      end.new

      counter.visit(Oxc.parse(SOURCE).root)

      assert_equal 3, counter.identifiers
    end

    test "stops where a visitor stops, when it does not walk on" do
      shallow = Class.new(Visitor) do
        attr_reader :seen

        def initialize
          @seen = []

          super
        end

        def visit_function_declaration(node)
          @seen << node.id["name"]
        end
      end.new

      shallow.visit(Oxc.parse(SOURCE).root)

      assert_equal ["bump"], shallow.seen
    end
  end
end
