# frozen_string_literal: true

require "test_helper"

module Oxc
  class TransformerTest < Minitest::Spec
    SQUARE = "const f = (a) => a ** 2; foo(f)"

    test "transforms with the options it was built with" do
      code = Transformer.new(target: "es2015").transform(SQUARE).code

      assert_equal "const f = (a) => Math.pow(a, 2);\nfoo(f);\n", code
    end

    test "merges what a call gives it over what it was built with" do
      code = Transformer.new(target: "es2015").transform(SQUARE, minify: true).code

      assert_equal "foo(e=>Math.pow(e,2));", code
    end

    test "lets a call override an option it was built with" do
      code = Transformer.new(target: "es2015").transform(SQUARE, target: "esnext").code

      assert_equal "const f = (a) => a ** 2;\nfoo(f);\n", code
    end

    test "answers call, so it can be handed to anything callable" do
      transformer = Transformer.new(target: "es2015")

      assert_equal "const f = (a) => Math.pow(a, 2);\nfoo(f);\n", transformer.call(SQUARE).to_s
    end

    test "builds another transformer from itself, leaving the first alone" do
      base = Transformer.new(target: "es2015")
      minifying = base.with(minify: true)

      assert_equal "foo(e=>Math.pow(e,2));", minifying.transform(SQUARE).code
      assert_equal "const f = (a) => Math.pow(a, 2);\nfoo(f);\n", base.transform(SQUARE).code
    end

    test "keeps its options to itself" do
      transformer = Transformer.new(target: "es2015")

      assert_predicate transformer, :frozen?
      assert_predicate transformer.options, :frozen?
      assert_equal({ target: "es2015" }, transformer.options)
    end

    test "reads a string key as the option it names" do
      assert_equal({ target: "es2015" }, Transformer.new("target" => "es2015").options)
    end

    test "prints what it was built with" do
      assert_equal %(#<Oxc::Transformer {target: "es2015"}>), Transformer.new(target: "es2015").inspect
    end

    test "refuses an option it does not read, when it is called" do
      error = assert_raises(OptionError) { Transformer.new(compress: true).transform("foo()") }

      assert_equal "compress is not an option for transform", error.message
    end
  end
end
