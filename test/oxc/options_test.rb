# frozen_string_literal: true

require "test_helper"

module Oxc
  class OptionsTest < Minitest::Spec
    test "writes what it was given as JSON" do
      assert_equal '{"sourcemap":true}', Options.new({ sourcemap: true }).to_json
    end

    test "writes nothing when it was given nothing" do
      assert_equal "{}", Options.new({}).to_json
    end

    test "reads a string key as the option it names" do
      assert_equal({ sourcemap: true }, Options.new({ "sourcemap" => true }).to_h)
    end

    test "drops an option that was given as nil" do
      assert_equal "{}", Options.new({ filename: nil }).to_json
    end

    test "keeps an option this side reads out of what the native side sees" do
      assert_equal "{}", Options.new({ strict: true }).to_json
    end

    test "names an option it knows about and does not support yet" do
      error = assert_raises(OptionError) { Options.new({ mangle_props: { include: "^_" } }) }

      assert_equal "mangle_props is not supported yet", error.message
    end

    test "refuses an option nobody reads" do
      error = assert_raises(OptionError) { Options.new({ nonsense: true }) }

      assert_equal "Unknown option: nonsense", error.message
    end

    test "names every option nobody reads" do
      error = assert_raises(OptionError) { Options.new({ nope: 1, nah: 2 }) }

      assert_equal "Unknown options: nope, nah", error.message
    end

    test "knows what parse reads" do
      expected = [
        :filename, :lang, :source_type, :ast_type, :ast, :ranges, :preserve_parens, :comments, :module_record,
        :symbols, :semantic_errors
      ]

      assert_equal expected, Options::PARSE
    end

    test "knows what transform reads" do
      expected = [
        :filename, :lang, :source_type, :cwd, :target, :jsx, :typescript, :assumptions, :decorator, :helpers,
        :define, :inject, :minify, :codegen, :sourcemap, :strict
      ]

      assert_equal expected, Options::TRANSFORM
    end

    test "knows every option anything reads" do
      expected = [
        :filename, :lang, :source_type, :compress, :mangle, :codegen, :sourcemap, :strict, :cwd, :target, :jsx,
        :typescript, :assumptions, :decorator, :helpers, :define, :inject, :minify, :ast_type, :ast, :ranges,
        :preserve_parens, :comments, :module_record, :symbols, :semantic_errors
      ]

      assert_equal expected, Options::KNOWN
    end

    test "knows what minify reads" do
      expected = [:filename, :lang, :source_type, :compress, :mangle, :codegen, :sourcemap, :strict]

      assert_equal expected, Options::MINIFY
    end

    test "refuses an option that has nothing to act on" do
      error = assert_raises(OptionError) do
        Options.serialize({ sourcemap: true }, [:filename], "a call")
      end

      assert_equal "sourcemap is not an option for a call", error.message
    end

    test "names every option that has nothing to act on" do
      error = assert_raises(OptionError) do
        Options.serialize({ sourcemap: true, filename: "a.js" }, [:lang], "a call")
      end

      assert_equal "sourcemap, filename are not options for a call", error.message
    end

    test "refuses an unknown option ahead of an unsupported one" do
      error = assert_raises(OptionError) do
        Options.serialize({ nonsense: 1, sourcemap: true }, [:lang], "a call")
      end

      assert_equal "Unknown option: nonsense", error.message
    end

    test "takes what it is allowed to read as an argument, so no option name can collide with it" do
      assert_equal '{"filename":"allowed"}', Options.serialize({ filename: "allowed" })
    end

    test "keeps what it read to itself" do
      options = Options.new({ sourcemap: true })

      assert_predicate options, :frozen?
      assert_predicate options.to_h, :frozen?
    end

    test "serializes in one step" do
      assert_equal '{"sourcemap":true}', Options.serialize({ sourcemap: true })
    end

    test "prints what it read" do
      assert_equal "#<Oxc::Options {sourcemap: true}>", Options.new({ sourcemap: true }).inspect
    end
  end
end
