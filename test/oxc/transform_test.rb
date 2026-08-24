# frozen_string_literal: true

require "test_helper"

module Oxc
  class TransformTest < Minitest::Spec
    PRIVATE = "class A { #p = 1; get() { return this.#p } }; foo(A)"

    test "strips the types TypeScript wrote" do
      code = Oxc.transform("const x: number = 1; console.log(x)", filename: "app.ts").code

      assert_equal "const x = 1;\nconsole.log(x);\n", code
    end

    test "leaves the code readable, because it was not asked to minify" do
      assert_equal "const x = 1;\nfoo(x);\n", Oxc.transform("const x = 1; foo(x)").code
    end

    test "minifies in the same pass when asked to" do
      code = Oxc.transform("const x: number = 1; console.log(x)", filename: "app.ts", minify: true).code

      assert_equal "const x=1;console.log(1);", code
    end

    test "lowers what a target cannot read" do
      code = Oxc.transform("const f = (a) => a ** 2; foo(f)", target: "es2015").code

      assert_equal "const f = (a) => Math.pow(a, 2);\nfoo(f);\n", code
    end

    test "leaves it alone for a target that can read it" do
      code = Oxc.transform("const f = (a) => a ** 2; foo(f)", target: "esnext").code

      assert_equal "const f = (a) => a ** 2;\nfoo(f);\n", code
    end

    test "reads a list of targets" do
      code = Oxc.transform("const f = (a) => a ** 2; foo(f)", target: ["es2015", "chrome58"]).code

      assert_equal "const f = (a) => Math.pow(a, 2);\nfoo(f);\n", code
    end

    test "compiles JSX to the automatic runtime" do
      code = Oxc.transform("const x = <div a={b} />; foo(x)", filename: "app.jsx", source_type: "module").code

      expected = %(import { jsx as _jsx } from "react/jsx-runtime";\nconst x = /* @__PURE__ */ _jsx("div", { a: b });\nfoo(x);\n)

      assert_equal expected, code
    end

    test "compiles JSX the classic way when told to" do
      code = Oxc.transform("const x = <div />; foo(x)", filename: "app.jsx", jsx: { runtime: "classic" }).code

      assert_equal "const x = /* @__PURE__ */ React.createElement(\"div\", null);\nfoo(x);\n", code
    end

    test "leaves JSX as written when it was told not to compile it" do
      code = Oxc.transform("const x = <div />; foo(x)", filename: "app.jsx", jsx: false).code

      assert_equal "const x = <div />;\nfoo(x);\n", code
    end

    test "drops an import that only carried types" do
      source = 'import type { A } from "./a"; import { b } from "./b"; foo(b)'
      code = Oxc.transform(source, filename: "a.ts", source_type: "module").code

      assert_equal "import { b } from \"./b\";\nfoo(b);\n", code
    end

    test "replaces what define named, and drops what that made unreachable" do
      assert_equal "", Oxc.transform("if (DEBUG) { foo() }", define: { "DEBUG" => "false" }).code
    end

    test "injects a default import for a name the source used" do
      code = Oxc.transform("foo(process)", inject: { "process" => "node:process" }, source_type: "module").code

      assert_equal "import process from \"node:process\";\nfoo(process);\n", code
    end

    test "injects a named import when it was given a source and a name" do
      code = Oxc.transform("foo(join)", inject: { "join" => ["node:path", "join"] }, source_type: "module").code

      assert_equal "import { join } from \"node:path\";\nfoo(join);\n", code
    end

    test "reports the runtime helpers the lowering it did needs" do
      helpers = Oxc.transform(PRIVATE, target: "es2015").helpers_used

      assert_equal ["classPrivateFieldGet2", "classPrivateFieldInitSpec"], helpers.keys.sort
      assert_equal "@oxc-project/runtime/helpers/classPrivateFieldGet2", helpers["classPrivateFieldGet2"]
    end

    test "reads the helpers from a global object when told to, so nothing is imported" do
      code = Oxc.transform(PRIVATE, target: "es2015", helpers: { mode: "external" }).code

      assert_equal "var _p = /* @__PURE__ */ new WeakMap();", code.lines.first.chomp
    end

    test "needs no helpers for source it did not have to lower" do
      assert_empty Oxc.transform("const x = 1; foo(x)").helpers_used
    end

    test "minifies to the target it was asked to lower for" do
      code = Oxc.transform("const f = (a) => a ** 2; foo(f)", target: "es2015", minify: true).code

      assert_equal "foo(e=>Math.pow(e,2));", code
    end

    test "lets the minifier keep its own target when it was given one" do
      source = "const f = (a) => a ** 2; foo(f)"
      code = Oxc.transform(source, target: "es2015", minify: { compress: { target: "esnext" } }).code

      assert_equal "foo(e=>e**2);", code
    end

    test "answers a map naming the file it was given" do
      map = JSON.parse(Oxc.transform("const x: number = 1; foo(x)", filename: "app.ts", sourcemap: true).map)

      assert_equal ["app.ts"], map["sources"]
    end

    test "takes a legal comment out of the code and reports it" do
      result = Oxc.transform("/*! (c) me */ foo()", codegen: { legal_comments: "external" })

      assert_equal ["/*! (c) me */"], result.legal_comments
    end

    test "writes a declaration file for the types it stripped" do
      source = "export const add = (a: number, b: number): number => a + b"
      result = Oxc.transform(source, filename: "add.ts", source_type: "module", typescript: { declaration: true })

      assert_equal "export const add = (a, b) => a + b;\n", result.code
      assert_equal "export declare const add: (a: number, b: number) => number;\n", result.declaration
    end

    test "writes no declaration file unless it was asked for one" do
      result = Oxc.transform("export const a: number = 1", filename: "a.ts", source_type: "module")

      assert_nil result.declaration
      assert_nil result.declaration_map
    end

    test "takes an assumption that lets it drop a helper" do
      source = "class A { x = 1 }; foo(A)"

      helpers = Oxc.transform(source, target: "es2015").helpers_used
      assumed = Oxc.transform(source, target: "es2015", assumptions: { set_public_class_fields: true })

      assert_equal ["defineProperty"], helpers.keys
      assert_empty assumed.helpers_used
      assert_equal "class A {\n\tconstructor() {\n\t\tthis.x = 1;\n\t}\n}\n;\nfoo(A);\n", assumed.code
    end

    test "compiles a decorator the way TypeScript did before the standard" do
      code = Oxc.transform("@dec class A {}; foo(A)", filename: "a.ts", decorator: { legacy: true }).code

      assert_equal %(var _decorate = require("@oxc-project/runtime/helpers/decorate");), code.lines.first.chomp
    end

    test "refuses a helpers mode it cannot read" do
      error = assert_raises(OptionError) { Oxc.transform("foo()", helpers: { mode: "nope" }) }

      assert_equal "Unknown helpers mode: nope. Expected runtime or external.", error.message
    end

    test "refuses a target it cannot read" do
      error = assert_raises(OptionError) { Oxc.transform("foo()", target: "es1066") }

      assert_equal "Invalid target 'es1066'.", error.message
    end

    test "refuses an option minify reads and it does not" do
      error = assert_raises(OptionError) { Oxc.transform("foo()", compress: true) }

      assert_equal "compress is not an option for transform", error.message
    end

    test "raises when it could not read the source at all" do
      error = assert_raises(SyntaxError) { Oxc.transform("const x = ;") }

      assert_equal "Unexpected token", error.message
      assert_predicate error.result, :panicked?
    end
  end
end
