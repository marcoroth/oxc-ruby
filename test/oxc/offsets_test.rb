# frozen_string_literal: true

require "test_helper"

module Oxc
  class OffsetsTest < Minitest::Spec
    SOURCE = "const café = 1; café(;"

    def label
      Oxc.minify(SOURCE, filename: "app.js")

      flunk "expected #{SOURCE.inspect} to be refused"
    rescue Oxc::SyntaxError => e
      e.diagnostics.first.labels.first
    end

    test "counts in UTF-8 bytes, which is what oxc counts in" do
      assert_equal 24, SOURCE.bytesize
      assert_equal 22, SOURCE.length

      assert_equal 23, label.start
      assert_equal 24, label.finish
    end

    test "reads its span back out of the source it came from" do
      assert_equal ";", label.slice(SOURCE)
    end

    test "prints the span it covers" do
      assert_equal "#<Oxc::Label 23..24>", label.inspect
    end

    test "keeps what it read to itself" do
      assert_predicate label, :frozen?
    end
  end
end
