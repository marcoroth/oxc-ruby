# frozen_string_literal: true

require "test_helper"

module Oxc
  class NodeTest < Minitest::Spec
    SOURCE = "let count = 0\nfunction bump() { count += 1; render(count) }"

    def root
      Oxc.parse(SOURCE).root
    end

    test "answers no node at all when the AST was not asked for" do
      assert_nil Oxc.parse(SOURCE, ast: false).root
    end

    test "wraps the program" do
      assert_equal "Program", root.type
      assert_equal 0, root.start
      assert_equal SOURCE.bytesize, root.finish
    end

    test "names itself the way a visitor answers it" do
      assert_equal "program", root.name
      assert_equal "variable_declaration", root.children.first.name
    end

    test "reads an acronym as one word" do
      assert_equal "ts_type_annotation", Node.new({ "type" => "TSTypeAnnotation" }).name
      assert_equal "jsx_element", Node.new({ "type" => "JSXElement" }).name
    end

    test "walks everything under it" do
      types = root.each.map(&:type)

      assert_equal 16, types.length
      assert_equal "Program", types.first
    end

    test "answers every node of one type" do
      assert_equal(["count", "bump", "count", "render", "count"], root.every("Identifier").map { |node| node["name"] })
    end

    test "reads a field as the node it holds" do
      declarator = root.children.first.declarations.first

      assert_equal "Identifier", declarator.id.type
      assert_equal "count", declarator.id["name"]
      assert_equal 0, declarator.init["value"]
    end

    test "reads a field that is not a node as it is" do
      assert_equal "let", root.children.first.kind
    end

    test "refuses a field it does not carry" do
      assert_raises(NoMethodError) { root.nonsense }
      refute_respond_to root, :nonsense
      assert_respond_to root, :body
    end

    test "reads its own source back" do
      assert_equal "count", root.at(SOURCE.index("count +=")).slice(SOURCE)
    end

    test "reaches the node a reference sits inside, which is what a rewrite needs" do
      reference = root.at(SOURCE.index("count +="))
      assignment = reference.ancestors.find { |node| node.type == "AssignmentExpression" }

      assert_equal "count += 1", assignment.slice(SOURCE)
    end

    test "answers the innermost node covering an offset" do
      node = root.at(SOURCE.index("render"))

      assert_equal "Identifier", node.type
      assert_equal "render", node.slice(SOURCE)
    end

    test "answers nothing for an offset outside it" do
      assert_nil root.at(SOURCE.bytesize + 10)
    end

    test "knows what it sits inside" do
      node = root.at(SOURCE.index("render"))

      assert_equal ["CallExpression", "ExpressionStatement", "BlockStatement", "FunctionDeclaration", "Program"], node.ancestors.map(&:type)
    end

    test "prints what it is, and what it carries in its own right" do
      assert_equal %(#<Oxc::Node Program 0..#{SOURCE.bytesize} sourceType="module">), root.inspect
      assert_equal %(#<Oxc::Node Identifier 4..9 name="count">), root.every("Identifier").first.inspect
      assert_equal %(#<Oxc::Node VariableDeclaration 0..13 kind="let">), root.children.first.inspect
    end

    test "leaves the nodes hanging off it out of what it carries" do
      declaration = root.children.first

      assert_equal ["kind"], declaration.scalars.keys
    end
  end
end
