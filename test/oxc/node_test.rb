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

    test "matches a camelCase field under its snake_case name" do
      declaration = Oxc.parse("class C { readonly x?: T }", filename: "a.ts").root.every("PropertyDefinition").first

      declaration => { type_annotation: { type: }, readonly: }

      assert_equal "TSTypeAnnotation", type
      assert readonly
    end

    test "leaves a method of its own alone, whatever a field is called" do
      assert_equal "program", root.underscored_type
      assert_equal 2, root.child_nodes.length
    end

    test "refuses a field it does not carry" do
      assert_raises(NoMethodError) { root.nonsense }
      refute_respond_to root, :nonsense
      assert_respond_to root, :body
    end

    test "reads its own source back" do
      assert_equal "count", root.at(SOURCE.index("count +=")).slice(SOURCE)
    end

    test "reads its own source back without being handed it" do
      assert_equal "count", root.at(SOURCE.index("count +=")).slice
      assert_equal SOURCE, root.slice
    end

    test "carries the source down to every descendant" do
      declaration = root.every("VariableDeclaration").first

      assert_equal "let count = 0", declaration.slice
      assert_equal "count", declaration.declarations.first.id.slice
    end

    test "says so when it has no source to read" do
      node = Oxc::Node.new({ "type" => "Identifier", "start" => 0, "end" => 1 })
      error = assert_raises(ArgumentError) { node.slice }

      assert_equal "this node does not know its source, so #slice needs it", error.message
      assert_equal "l", node.slice(SOURCE)
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

    test "answers a node's fields by name in a pattern" do
      root.every("VariableDeclarator").first => { type:, id: { name: }, init: { value: } }

      assert_equal "VariableDeclarator", type
      assert_equal "count", name
      assert_equal 0, value
    end

    test "matches on nothing it does not carry" do
      identifier = root.every("Identifier").first

      assert((identifier in { type: "Identifier" }))
      refute((identifier in { type: "Identifier", nonsense: String }))
      refute((identifier in { type: "Literal" }))
    end

    test "binds the rest of a node's fields" do
      root.every("VariableDeclarator").first => { type: String, **rest }

      assert_equal [:id, :init, :start, :end], rest.keys
    end

    test "answers the field names it carries" do
      assert_equal ["type", "id", "init", "start", "end"], root.every("VariableDeclarator").first.keys
    end

    test "answers its own fields as a hash" do
      node = root.every("VariableDeclarator").first

      assert_equal ["type", "id", "init", "start", "end"], node.to_h.keys
      assert_equal "VariableDeclarator", node.to_h["type"]
    end

    test "serializes back to the ESTree JSON it came from" do
      node = root.every("VariableDeclarator").first.id

      assert_equal %({"type":"Identifier","name":"count","start":4,"end":9}), node.to_json
    end

    test "serializes when it sits inside something else" do
      node = root.every("VariableDeclarator").first.id

      assert_equal %({"node":{"type":"Identifier","name":"count","start":4,"end":9}}), { node: node }.to_json
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

    test "prints what it is, and every field it carries" do
      expected = <<~INSPECT.chomp
        #<Oxc::Node Program range=[0, #{SOURCE.bytesize}] body=[... 2 items] sourceType="module" hashbang=nil>
      INSPECT

      assert_equal expected, root.inspect
      assert_equal %(#<Oxc::Node Identifier range=[4, 9] name="count">), root.every("Identifier").first.inspect
      assert_equal %(#<Oxc::Node VariableDeclaration range=[0, 13] kind="let" declarations=[... 1 item]>),
                   root.child_nodes.first.inspect
    end

    test "prints what a field holds, so there is something to reach for" do
      declarator = root.every("VariableDeclarator").first

      expected = <<~INSPECT.chomp
        #<Oxc::Node VariableDeclarator range=[4, 13] id=#<Oxc::Node Identifier> init=#<Oxc::Node Literal>>
      INSPECT

      assert_equal expected, declarator.inspect
    end

    test "prints how many a field holds" do
      source = %(export function bump(x, y) {})
      declaration = Oxc.parse(source, source_type: "module").root.every("FunctionDeclaration").first

      expected = <<~INSPECT.chomp
        #<Oxc::Node FunctionDeclaration range=[7, 29] id=#<Oxc::Node Identifier> generator=false async=false params=[... 2 items] body=#<Oxc::Node BlockStatement> expression=false>
      INSPECT

      assert_equal expected, declaration.inspect
    end

    test "prints a field holding nothing, so no field goes unaccounted for" do
      source = %(class C { declare private readonly x?: T })
      declaration = Oxc.parse(source, filename: "a.ts").root.every("PropertyDefinition").first

      expected = <<~INSPECT.chomp
        #<Oxc::Node PropertyDefinition range=[10, 40] decorators=[] key=#<Oxc::Node Identifier> typeAnnotation=#<Oxc::Node TSTypeAnnotation> value=nil computed=false static=false declare=true override=false optional=true definite=false readonly=true accessibility="private">
      INSPECT

      assert_equal expected, declaration.inspect
    end

    test "answers the fields it carries, without the span it always carries" do
      assert_equal ["kind", "declarations"], root.child_nodes.first.fields.keys
      assert_equal ["type", "kind", "declarations", "start", "end"], root.child_nodes.first.keys
    end
  end
end
