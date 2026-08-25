<h2 align="center">⚓ Oxc for Ruby</h2>

<h4 align="center">A collection of high-performance tools for JavaScript and TypeScript written in Rust.</h4>

<div align="center">Ruby bindings for <a href="https://oxc.rs">Oxc</a>, the JavaScript Oxidation Compiler.</div><br/>

<p align="center">
  <a href="https://rubygems.org/gems/oxc"><img alt="Gem Version" src="https://img.shields.io/gem/v/oxc"></a>
  <a href="https://oxc.rs"><img alt="Documentation" src="https://img.shields.io/badge/oxc.rs-documentation-green"></a>
  <a href="https://github.com/marcoroth/oxc-ruby/blob/main/LICENSE.txt"><img alt="License" src="https://img.shields.io/github/license/marcoroth/oxc-ruby"></a>
  <a href="https://github.com/marcoroth/oxc-ruby/issues"><img alt="Issues" src="https://img.shields.io/github/issues/marcoroth/oxc-ruby"></a>
</p>

<br/>

### What is Oxc for Ruby?

Ruby bindings for [Oxc](https://oxc.rs), a collection of high-performance tools for JavaScript and TypeScript written in Rust. Parse, transform and minify JavaScript from Ruby, without the need for a JavaScript runtime.

Everything here is Oxc doing the work. For what the options mean and what it can do, [oxc.rs](https://oxc.rs) is the reference.

### Installation

```bash
bundle add oxc
```

Anywhere a precompiled gem is not published, the gem builds from source and needs the [Rust toolchain](https://rustup.rs) at 1.96 or newer.

### Usage

#### Minifying

```ruby
Oxc.minify("const x = 1; console.log(x)").code
#=> "console.log(1);"
```

Compressing and mangling are both on. Either can be switched off, or given settings of its own.

```ruby
Oxc.minify(source, compress: false).code
Oxc.minify(source, mangle: { top_level: false, reserved: ["exports"] }).code
Oxc.minify(source, compress: { drop_console: true, drop_debugger: false }).code
```

#### Transforming

`transform` compiles TypeScript and JSX away, and lowers what a browser you support cannot read. It leaves the output readable unless it is asked for otherwise.

```ruby
Oxc.transform("const x: number = 1; console.log(x)", filename: "app.ts").code
#=> "const x = 1;\nconsole.log(x);\n"

Oxc.transform("const f = (a) => a ** 2; foo(f)", target: "es2015").code
#=> "const f = (a) => Math.pow(a, 2);\nfoo(f);\n"

Oxc.transform(source, filename: "app.jsx", source_type: "module").code
#=> "import { jsx as _jsx } from \"react/jsx-runtime\";\n..."
```

Minifying in the same call reads the source once instead of twice. The minifier lowers to the same target, so it never undoes the lowering the transform just did.

```ruby
Oxc.transform(source, filename: "app.ts", target: "es2020", minify: true).code
```

`define` replaces a name wherever it appears, and whatever that makes unreachable is dropped with it. `inject` adds an import for a name the source used without importing.

```ruby
Oxc.transform("if (DEBUG) { log() }", define: { "DEBUG" => "false" }).code
#=> ""

Oxc.transform("foo(process)", inject: { "process" => "node:process" }, source_type: "module").code
#=> "import process from \"node:process\";\nfoo(process);\n"
```

#### Declaration files

Asking for a declaration writes the `.d.ts` beside the code, from the types it just stripped.

```ruby
result = Oxc.transform(source, filename: "add.ts", source_type: "module", typescript: { declaration: true })

result.code         #=> "export const add = (a, b) => a + b;\n"
result.declaration  #=> "export declare const add: (a: number, b: number) => number;\n"
```

`declaration_map` comes with it when `sourcemap: true` is set.

#### Decorators

```ruby
Oxc.transform(source, filename: "a.ts", decorator: { legacy: true, emit_decorator_metadata: true }).code
```

`legacy` is the version of decorators TypeScript shipped before the standard, matching `experimentalDecorators`.

#### Runtime helpers

Lowering sometimes needs a helper function, and by default oxc imports it from the `@oxc-project/runtime` npm package. In an application with no npm packages that import resolves to nothing, so `helpers_used` says what a transform reached for.

```ruby
result = Oxc.transform(source, target: "es2015")

result.helpers_used
#=> {"classPrivateFieldGet2" => "@oxc-project/runtime/helpers/classPrivateFieldGet2"}
```

Leaving `target` unset asks for no lowering, and needs no helpers. The other way out is `external`, which reads the helpers off a global `babelHelpers` object you provide.

```ruby
Oxc.transform(source, target: "es2015", helpers: { mode: "external" }).code
```

An assumption can remove the need for a helper altogether. Telling oxc that public class fields shadow nothing lets it assign them directly, and the helper import goes away.

```ruby
Oxc.transform("class A { x = 1 }", target: "es2015").helpers_used
#=> {"defineProperty" => "@oxc-project/runtime/helpers/defineProperty"}

Oxc.transform("class A { x = 1 }", target: "es2015", assumptions: { set_public_class_fields: true }).helpers_used
#=> {}
```

The assumptions are `ignore_function_length`, `no_document_all`, `object_rest_no_symbols`, `pure_getters` and `set_public_class_fields`. oxc says so when one of them is not implemented for the transform it would apply to.

#### Reading TypeScript

The grammar comes from the filename, and `lang` says so where the filename cannot.

```ruby
Oxc.minify(source, filename: "app.ts").code
Oxc.minify(source, lang: "tsx").code
```

#### Source maps

`map` is the source map as JSON text, so a caller who only writes it out never pays to parse it.

```ruby
result = Oxc.minify(source, filename: "app.js", sourcemap: true)

result.code
JSON.parse(result.map)
```

#### Keeping the output readable

```ruby
Oxc.minify("const x = 1; foo(x)", codegen: { remove_whitespace: false }).code
#=> "foo(1);\n"
```

#### Legal comments

A legal comment is one carrying `@license` or `@preserve`, or starting with `//!` or `/*!`. They can stay inline, move to the end, or come back separately.

```ruby
result = Oxc.minify("/*! (c) me */ foo()", codegen: { legal_comments: "external" })

result.code            #=> "foo();"
result.legal_comments  #=> ["/*! (c) me */"]
```

#### Parsing

`parse` answers the [ESTree](https://github.com/estree/estree) AST oxc read, as plain Ruby hashes and arrays.

```ruby
program = Oxc.parse("let a = 1").program

program["type"]                                            #=> "Program"
program["body"].first["kind"]                              #=> "let"
program["body"].first["declarations"].first["id"]["name"]  #=> "a"
```

Parsing never raises for source it could not read. The parser recovers, so what it could not read comes back in `errors`, and `panicked?` says whether it gave up. `validate!` raises on demand.

```ruby
parsed = Oxc.parse("const x = ;")

parsed.errors.map(&:message)  #=> ["Unexpected token"]
parsed.panicked?              #=> true
parsed.validate!              #=> raises Oxc::SyntaxError
```

The AST is by far the largest thing crossing the boundary, so `ast: false` skips building it. Use it when only the diagnostics matter.

```ruby
Oxc.parse(source, ast: false).errors?
```

Comments come back beside the AST, and a hashbang reads as the line comment it looks like.

```ruby
Oxc.parse("// hi\nfoo() /* there */").comments.map { |comment| [comment.type, comment.value] }
#=> [["Line", " hi"], ["Block", " there "]]
```

A few more knobs: `ranges: true` adds a `range` pair to every node, `preserve_parens: false` drops the `ParenthesizedExpression` wrappers, `ast_type: "js"` leaves the TypeScript properties off a TypeScript AST, and `semantic_errors: true` reports what only semantic analysis can see.

```ruby
Oxc.parse("let a; let a;", semantic_errors: true).errors.map(&:message)
#=> ["Identifier `a` has already been declared"]
```

#### Walking the AST

`root` answers the program as an `Oxc::Node`, which walks, reads its fields by name, and knows what it sits inside.

```ruby
root = Oxc.parse(source).root

root.type                 #=> "Program"
root.every("Identifier")  #=> every identifier in the file
root.at(offset)           #=> the innermost node covering a byte offset
root.each                 #=> an Enumerator over every node
```

A field comes back as a node when it holds one, so reads chain.

```ruby
declaration = root.children.first

declaration.kind
#=> "let"

declaration.declarations.first.id["name"]
#=> "count"
```

`ancestors` is what a rewrite needs, since a reference sits inside the expression that has to be replaced.

```ruby
reference = root.at(source.index("count +="))
reference.ancestors.find { |node| node.type == "AssignmentExpression" }.slice(source)
#=> "count += 1"
```

`Oxc::Visitor` answers a node with the method named after its type, and walks through anything nothing answers.

```ruby
class Reads < Oxc::Visitor
  def visit_assignment_expression(node)
    puts "#{node.left["name"]} #{node.operator}"

    visit_children(node)
  end
end

Reads.new.visit(Oxc.parse(source))
```

It takes a parse result or a node, so the common case needs no `root`. A result with no AST is nothing to walk and visits nothing.

There is one node class, not one per type, so a type the gem has never seen still walks and still answers. The types and their fields are [ESTree](https://github.com/estree/estree). For the TypeScript and JSX nodes, which ESTree does not cover, oxc publishes the exact shapes it emits as [`@oxc-project/types`](https://www.npmjs.com/package/@oxc-project/types).

#### Rewriting

`Oxc::MutationVisitor` records what to do to a node and splices the original text at the end, so everything it did not touch survives byte for byte, comments and indentation included.

```ruby
class Renamer < Oxc::MutationVisitor
  def visit_identifier(node)
    replace(node, "renamed") if node["name"] == "count"
  end
end

Renamer.new.rewrite("let count = 1 // keep me")
#=> "let renamed = 1 // keep me"
```

`replace`, `remove`, `insert_before`, `insert_after` and `wrap` are the operations, and each takes a node. Spans are exact, so removing `debugger;` removes what the node covered and leaves the newline after it alone.

Walking into a node that was replaced would edit text that is no longer there, so it stops. Two edits over the same span raise `Oxc::MutationVisitor::Overlap` instead of quietly producing something broken.

What goes in is text, so a node can become anything, including several statements or nothing at all. Nothing checks it on the way, so the result is read back afterwards and refused if it stopped being JavaScript.

```ruby
Breaker.new.rewrite("foo(data)")
#=> Oxc::MutationVisitor::Invalid: what was rewritten no longer reads as JavaScript: Unexpected token
```

Pass `verify: false` for a fragment that was never going to parse on its own.

`parsed` reaches what the source parsed to, so a rewrite can ask for symbols and drive from them. That is the difference between rewriting a name and rewriting the right one.

```ruby
class ToState < Oxc::MutationVisitor
  def rewrite(source) = super(source, symbols: true)

  def visit_identifier(node)
    reference = parsed.symbols.fetch("declared").flat_map { |symbol| symbol["references"] }
      .find { |found| found["start"] == node.start }

    replace(node, %(state.get("#{node["name"]}"))) if reference && !reference["write"]
  end
end
```

Drive from references, not from every `Identifier`. That is what keeps a declaration, a shadowed local, and a same-named property out of the rewrite.

#### What a file declared, and what it only used

`symbols: true` answers every binding with the span it was declared at and the spans of every reference to it, plus the names the file used without declaring.

```ruby
symbols = Oxc.parse(source, symbols: true).symbols

symbols["declared"]
#=> [{"name" => "count", "root" => true, "declaration" => {...}, "references" => [{...}]}]

symbols["unresolved"]
#=> [{"name" => "fetch", "references" => [{...}]}]
```

Every reference says whether it read the name, wrote it, or both, which comes from oxc's scope analysis and not from the shape of the tree.

```ruby
# let count = 0; function bump() { count += 1; render(count) }; count = 5
references.map { |reference| [reference["read"], reference["write"]] }
#=> [[true, true], [true, false], [false, true]]
```

`root` says whether the file declared it at the top level. Every span counts in UTF-8 bytes, so a rewrite can splice the source directly with `String#byteslice`, which is how the JavaScript ecosystem edits code without reprinting it.

#### What a file imports and exports

`module_record: true` answers the module's imports and exports without walking the AST for them.

```ruby
record = Oxc.parse(source, source_type: "module", module_record: true).module_record

record["has_module_syntax"]
record["static_imports"].map { |import| import["module_request"]["value"] }
#=> ["./a", "./b"]

record["static_exports"]
record["dynamic_imports"]
record["import_metas"]
```

Every entry carries the span it was written at, so it maps back onto the source. An import entry says whether it was a TypeScript `import type`, and an export says which module it came from.

#### Reusing options

`Oxc::Transformer` and `Oxc::Minifier` each hold a set of options to use across many files. Options given to a call are merged over the ones the object was built with, so the ones that belong to the project are written once and the ones that belong to a single file travel with it.

```ruby
transformer = Oxc::Transformer.new(target: "es2020", jsx: { runtime: "automatic" })

transformer.transform(source, filename: "app.tsx").code
transformer.with(minify: true).transform(source, filename: "app.ts").code

minifier = Oxc::Minifier.new(compress: { drop_console: true })

minifier.minify(source).code
```

Both answer `call` as well, so either can be handed to anything expecting something callable.

```ruby
minifier.call(source).to_s
```

They are separate objects because they read separate options. `minify` reads `compress` and `mangle`, while `transform` reads `target`, `jsx` and the rest, which is the same split upstream draws between the `oxc-minify` and `oxc-transform` packages.

### Options

| Option        | Type            | Description                                                                      |
|---------------|-----------------|----------------------------------------------------------------------------------|
| `filename`    | `String`        | The name to use in diagnostics, in the source map, and to read the grammar from. |
| `lang`        | `String`        | `js`, `jsx`, `ts`, `tsx` or `dts`, when the filename does not say.               |
| `source_type` | `String`        | `script`, `module`, `commonjs` or `unambiguous`.                                 |
| `compress`    | `bool`, `Hash`  | Whether to compress, and how.                                                    |
| `mangle`      | `bool`, `Hash`  | Whether to rename what nothing outside can see, and how.                         |
| `codegen`     | `bool`, `Hash`  | How to print the result.                                                         |
| `sourcemap`   | `bool`          | Whether to answer a source map alongside the code.                               |
| `strict`      | `bool`          | Whether to raise on any diagnostic. Off, only unusable output raises.            |

`parse` reads these instead:

| Option            | Type     | Description                                                                |
|-------------------|----------|----------------------------------------------------------------------------|
| `ast`             | `bool`   | Whether to build the AST at all. On by default.                            |
| `ast_type`        | `String` | `js` or `ts`, to include or leave out the TypeScript properties.           |
| `ranges`          | `bool`   | Whether every node carries a `range` pair.                                 |
| `preserve_parens` | `bool`   | Whether parentheses become `ParenthesizedExpression` nodes. On by default. |
| `comments`        | `bool`   | Whether to collect the comments. On by default.                            |
| `semantic_errors` | `bool`   | Whether to also report what semantic analysis finds.                       |

`transform` reads these instead of `compress` and `mangle`:

| Option       | Type              | Description                                                        |
|--------------|-------------------|--------------------------------------------------------------------|
| `target`     | `String`, `Array` | The ECMAScript version or browsers to lower for, such as `es2015`. |
| `jsx`        | `bool`, `Hash`    | Whether to compile JSX, and how. `false` leaves it as written.     |
| `typescript` | `Hash`            | How to compile TypeScript.                                         |
| `helpers`    | `Hash`            | Where the runtime helpers come from, `runtime` or `external`.      |
| `define`     | `Hash`            | Names to replace wherever they appear.                             |
| `inject`     | `Hash`            | Names to import where the source used them without importing.      |
| `minify`     | `bool`, `Hash`    | Whether to minify in the same pass, and how.                       |
| `cwd`        | `String`          | What relative paths in other options are relative to.              |

An option nobody reads is refused, and so is one inside a nested hash:

```ruby
Oxc.minify(source, nonsense: true)
#=> Oxc::OptionError: Unknown option: nonsense

Oxc.minify(source, compress: { nonsense: true })
#=> Oxc::OptionError: Invalid options: unknown field `nonsense`, expected one of `target`, ...
```

### Results

Each call answers its own result, so no result carries a field the call that produced it can never fill.

* `Oxc.minify` answers an `Oxc::MinifyResult`
* `Oxc.transform` answers an `Oxc::TransformResult`
* `Oxc.parse` answers an `Oxc::ParseResult`

`Oxc::MinifyResult` and `Oxc::TransformResult` are both an `Oxc::Result`, so anything reading `code` or `to_s` takes either one. `Oxc::ParseResult` stands on its own, because a parse answers a tree and has no code to print.

#### What every result answers

```ruby
result = Oxc.minify("const x = 1; console.log(x)")

result.diagnostics  #=> everything oxc had to say
result.errors       #=> the error-severity half of it
result.warnings     #=> the warning-severity half
result.errors?
result.warnings?
result.panicked?    #=> whether oxc gave up on the source
result.validate!    #=> itself, or raises Oxc::SyntaxError
```

`validate!` means something slightly different for each. `Oxc::MinifyResult` and `Oxc::TransformResult` raise only when there is nothing usable to answer with, and `strict: true` widens that to any error at all. `Oxc::ParseResult` raises on any error, because a parse routinely answers a usable tree alongside them.

#### Minify and transform

```ruby
result = Oxc.minify("const x = 1; console.log(x)")

result.code            #=> "console.log(1);"
result.to_s            #=> "console.log(1);"
result.map             #=> nil, or the source map as JSON text
result.legal_comments  #=> []
```

A transform adds what only a transform can answer.

```ruby
result = Oxc.transform(source, filename: "app.ts", sourcemap: true, typescript: { declaration: true })

result.declaration      #=> the .d.ts it wrote
result.declaration_map  #=> its source map, as JSON text
result.helpers_used     #=> the runtime helpers its lowering reached for
```

#### Parse

```ruby
parsed = Oxc.parse(source, source_type: "module", module_record: true)

parsed.program        #=> the ESTree AST, or nil when ast: false
parsed.module_record  #=> the imports and exports, when asked for
parsed.symbols        #=> the bindings and their references, when asked for
parsed.comments       #=> Array[Oxc::Comment]
```

### Diagnostics

oxc's parser recovers, so source it could not fully read still produces a result, and what it could not read comes back as diagnostics. When a call does raise, `Oxc::SyntaxError` carries the result it came from, whichever of the three that was.

```ruby
begin
  Oxc.minify("const x = ;", filename: "broken.js")
rescue Oxc::SyntaxError => e
  e.message                          #=> "Unexpected token"
  e.diagnostics.first.codeframe      #=> the frame below
  e.result.panicked?                 #=> true
end
```

```
  x Unexpected token
   ,-[broken.js:1:11]
 1 | const x = ;
   :           ^
   `----
```

A diagnostic's labels count in **UTF-8 bytes**, which is what oxc counts in and what Ruby slices by:

```ruby
label = e.diagnostics.first.labels.first

label.start          #=> 10
label.finish         #=> 11
label.slice(source)  #=> ";"
```

### Development

The gem is a C extension over a Rust crate. `rust/` builds a static library and generates the C header with [cbindgen](https://github.com/mozilla/cbindgen), `ext/oxc/` wraps it, and `lib/` is the Ruby API over that.

```bash
bin/setup
bundle exec rake
```

`sig/` is generated from the `#:` annotations next to the code. Regenerate it with `rake rbs` after changing a signature, and CI checks that it matches.

### Acknowledgements

[Oxc](https://oxc.rs) is maintained at [oxc-project/oxc](https://github.com/oxc-project/oxc) and is part of [VoidZero](https://voidzero.dev)'s toolchain for JavaScript. This gem only calls into it. Every parser, transformer and minifier feature comes from there.

Thank you to all of them.

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcoroth/oxc-ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/marcoroth/oxc-ruby/blob/main/CODE_OF_CONDUCT.md).

Issues with parsing, transforming or minifying itself belong [upstream](https://github.com/oxc-project/oxc/issues), since this gem does none of that. Issues with the Ruby API, the build, or the bindings belong here.

### License

The Ruby, C, and Rust code in this gem is available under the terms of the [MIT License](https://opensource.org/licenses/MIT).

It builds against [Oxc](https://github.com/oxc-project/oxc), which is MIT licensed and carries some Apache-2.0 code of its own. A copy of both travels with the gem in [`licenses/`](licenses) so that whoever received it has the terms in hand.
