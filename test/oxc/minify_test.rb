# frozen_string_literal: true

require "test_helper"

module Oxc
  class MinifyTest < Minitest::Spec
    FUNCTION = 'function greet(longName) { return "hi " + longName }; foo(greet)'

    test "compresses what it was given" do
      assert_equal "console.log(1);", Oxc.minify("const x = 1; console.log(x)").code
    end

    test "mangles the names nothing outside can see" do
      assert_equal "function e(e){return`hi `+e}foo(e);", Oxc.minify(FUNCTION).code
    end

    test "leaves every name as written when it was not asked to mangle" do
      code = Oxc.minify(FUNCTION, mangle: false).code

      assert_equal "function greet(longName){return`hi `+longName}foo(greet);", code
    end

    test "leaves the top level alone when told to" do
      code = Oxc.minify(FUNCTION, mangle: { top_level: false }).code

      assert_equal "function greet(e){return`hi `+e}foo(greet);", code
    end

    test "keeps a name it was told to reserve" do
      code = Oxc.minify(FUNCTION, mangle: { reserved: ["longName"] }).code

      assert_equal "function e(longName){return`hi `+longName}foo(e);", code
    end

    test "compresses nothing when it was not asked to" do
      assert_equal "const e=1;console.log(e);", Oxc.minify("const x = 1; console.log(x)", compress: false).code
    end

    test "drops console calls when told to" do
      assert_equal "foo();", Oxc.minify("console.log(1); foo()", compress: { drop_console: true }).code
    end

    test "drops a debugger statement by default, and keeps it when told to" do
      assert_equal "foo();", Oxc.minify("debugger; foo()").code
      assert_equal "debugger;foo();", Oxc.minify("debugger; foo()", compress: { drop_debugger: false }).code
    end

    test "drops a label it was told to drop" do
      assert_equal "", Oxc.minify("outer: for (;;) { break outer }", compress: { drop_labels: ["outer"] }).code
    end

    test "keeps the whitespace when it was told not to remove it" do
      assert_equal "foo(1);\n", Oxc.minify("const x = 1; foo(x)", codegen: { remove_whitespace: false }).code
    end

    test "reads TypeScript when the filename says so" do
      code = Oxc.minify("const x: number = 1; console.log(x)", filename: "app.ts").code

      assert_equal "const x:number=1;console.log(1);", code
    end

    test "reads TypeScript when lang says so, whatever the filename" do
      code = Oxc.minify("const x: number = 1; console.log(x)", lang: "ts").code

      assert_equal "const x:number=1;console.log(1);", code
    end

    test "reads a symbol as the string it names" do
      assert_equal "a?.b;", Oxc.minify("a?.b", lang: :js, source_type: :module).code
    end

    test "answers a result that prints as its code" do
      result = Oxc.minify("const x = 1; console.log(x)")

      assert_equal "console.log(1);", result.to_s
      assert_empty result.diagnostics
      assert_nil result.map
    end

    test "answers nothing for nothing" do
      assert_equal "", Oxc.minify("").code
    end

    test "keeps a legal comment inline when told to" do
      code = Oxc.minify("/*! keep me */ const x = 1; foo(x)", codegen: { legal_comments: "inline" }).code

      assert_equal "/*! keep me */\nfoo(1);", code
    end

    test "takes a legal comment out of the code and reports it" do
      result = Oxc.minify("/*! keep me */ foo()", codegen: { legal_comments: "external" })

      assert_equal "foo();", result.code
      assert_equal ["/*! keep me */"], result.legal_comments
    end

    test "reports no legal comments when there were none" do
      assert_empty Oxc.minify("foo()").legal_comments
    end
  end
end
