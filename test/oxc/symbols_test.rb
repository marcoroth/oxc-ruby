# frozen_string_literal: true

require "test_helper"

module Oxc
  class SymbolsTest < Minitest::Spec
    SOURCE = "let count = 0\nfunction bump() { const step = 1; count += step; fetch(url) }\nbump()"

    def symbols(source = SOURCE, **)
      Oxc.parse(source, symbols: true, **).symbols
    end

    def declared(name)
      symbols["declared"].find { |symbol| symbol["name"] == name }
    end

    test "reads nothing about the symbols unless it was asked to" do
      assert_nil Oxc.parse(SOURCE).symbols
    end

    test "names everything the file declared" do
      assert_equal(["count", "bump", "step"], symbols["declared"].map { |symbol| symbol["name"] })
    end

    test "says which of them the file declared at the top level" do
      assert declared("count")["root"]
      assert declared("bump")["root"]
      refute declared("step")["root"]
    end

    test "says where a name was declared" do
      declaration = declared("count")["declaration"]

      assert_equal "count", SOURCE.byteslice(declaration["start"], declaration["end"] - declaration["start"])
    end

    test "says where every reference to it was written" do
      references = declared("count")["references"]

      assert_equal 1, references.length
      assert_equal "count", SOURCE.byteslice(references.first["start"], 5)
    end

    test "says whether each reference read the name, wrote it, or both" do
      source = "let count = 0\nfunction bump() { count += 1; render(count) }\ncount = 5"
      references = symbols(source)["declared"].find { |symbol| symbol["name"] == "count" }["references"]

      assert_equal([[true, true], [true, false], [false, true]],
                   references.map { |reference| [reference["read"], reference["write"]] })
    end

    test "names what the file used without declaring" do
      assert_equal(["fetch", "url"], symbols["unresolved"].map { |symbol| symbol["name"] })
    end

    test "says where each of those was used" do
      fetch = symbols["unresolved"].find { |symbol| symbol["name"] == "fetch" }

      assert_equal 1, fetch["references"].length
      assert_equal "fetch", SOURCE.byteslice(fetch["references"].first["start"], 5)
    end
  end
end
