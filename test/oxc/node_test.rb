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
      assert_equal "program", root.underscored_type
      assert_equal "variable_declaration", root.child_nodes.first.underscored_type
    end

    test "reads an acronym as one word" do
      assert_equal "ts_type_annotation", Node.new({ "type" => "TSTypeAnnotation" }).underscored_type
      assert_equal "jsx_element", Node.new({ "type" => "JSXElement" }).underscored_type
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
      declarator = root.child_nodes.first.declarations.first

      assert_equal "Identifier", declarator.id.type
      assert_equal "count", declarator.id["name"]
      assert_equal 0, declarator.init["value"]
    end

    test "reads a field that is not a node as it is" do
      assert_equal "let", root.child_nodes.first.kind
    end

    test "answers the ESTree field and not a method of its own" do
      identifier = root.every("Identifier").first

      assert_equal "count", identifier.name
      assert_equal "identifier", identifier.underscored_type
    end

    test "answers the ESTree field on a node carrying children of its own" do
      element = Oxc.parse("<div><span/></div>", filename: "App.jsx").root.every("JSXElement").first

      assert_equal ["JSXElement"], element.children.map(&:type)
      assert_equal ["JSXOpeningElement", "JSXElement", "JSXClosingElement"], element.child_nodes.map(&:type)
    end

    test "answers the ESTree field on a node carrying attributes of its own" do
      opening = Oxc.parse(%(<div id="a" />), filename: "App.jsx").root.every("JSXOpeningElement").first

      assert_equal(["id"], opening.attributes.map { |attribute| attribute.name.name })
    end

    test "answers import attributes, which name a field the walker once shadowed" do
      source = %(import a from "./a" with { type: "json" })
      declaration = Oxc.parse(source, source_type: "module").root.child_nodes.first

      assert_equal(["type"], declaration.attributes.map { |attribute| attribute.key.name })
    end

    test "reads a camelCase field by its snake_case name" do
      source = %(class C extends B { declare readonly x?: T })
      declaration = Oxc.parse(source, filename: "a.ts").root.every("PropertyDefinition").first

      assert_equal "TSTypeAnnotation", declaration.type_annotation.type
      assert_equal declaration.typeAnnotation.type, declaration.type_annotation.type
      assert_equal "B", Oxc.parse(source, filename: "a.ts").root.every("ClassDeclaration").first.super_class.name
      assert_equal "module", root.source_type
    end

    test "answers to a field by either name" do
      declaration = Oxc.parse("class C { x?: T }", filename: "a.ts").root.every("PropertyDefinition").first

      assert_respond_to declaration, :type_annotation
      assert_respond_to declaration, :typeAnnotation
      refute_respond_to declaration, :type_nonsense
    end

    test "leaves a method of its own alone, whatever a field is called" do
      assert_equal "program", root.underscored_type
      assert_equal 2, root.child_nodes.length
    end

    test "answers its own fields as a hash" do
      node = root.every("VariableDeclarator").first

      assert_equal ["type", "id", "init", "start", "end"], node.to_h.keys
      assert_equal "VariableDeclarator", node.to_h["type"]
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
      assert_equal %(#<Oxc::Node VariableDeclaration 0..13 kind="let">), root.child_nodes.first.inspect
    end

    test "leaves the nodes hanging off it out of what it carries" do
      declaration = root.child_nodes.first

      assert_equal ["kind"], declaration.scalars.keys
    end
  end
end
