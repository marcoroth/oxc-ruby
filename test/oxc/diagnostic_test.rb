# frozen_string_literal: true

require "test_helper"

module Oxc
  class DiagnosticTest < Minitest::Spec
    def diagnostic(source = "const x = ;", **)
      Oxc.minify(source, **)

      flunk "expected #{source.inspect} to be refused"
    rescue Oxc::SyntaxError => e
      e.diagnostics.first
    end

    test "says what it could not read" do
      assert_equal "Unexpected token", diagnostic.message
    end

    test "knows how bad it is" do
      assert_equal "error", diagnostic.severity
      assert_predicate diagnostic, :error?
      refute_predicate diagnostic, :warning?
    end

    test "points at the source with a codeframe naming the file, as plain text" do
      codeframe = diagnostic("const x = ;", filename: "broken.js").codeframe

      assert_equal "\n  x Unexpected token\n   ,-[broken.js:1:11]\n 1 | const x = ;\n   :           ^\n   `----\n", codeframe
    end

    test "prints as its message" do
      assert_equal "Unexpected token", diagnostic.to_s
    end

    test "prints what it is" do
      assert_equal %(#<Oxc::Diagnostic error "Unexpected token">), diagnostic.inspect
    end

    test "keeps what it read to itself" do
      assert_predicate diagnostic, :frozen?
      assert_predicate diagnostic.labels, :frozen?
    end
  end
end
