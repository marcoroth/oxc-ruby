# frozen_string_literal: true

require "test_helper"

module Oxc
  class SourcemapTest < Minitest::Spec
    test "answers no map when it was not asked for one" do
      assert_nil Oxc.minify("const x = 1; foo(x)").map
    end

    test "answers a map naming the file it was given" do
      map = JSON.parse(Oxc.minify("const x = 1; foo(x)", filename: "app.js", sourcemap: true).map)

      assert_equal 3, map["version"]
      assert_equal ["app.js"], map["sources"]
      refute_empty map["mappings"]
    end

    test "leaves the map as text, for a caller who only writes it out" do
      assert_kind_of String, Oxc.minify("foo(1)", filename: "app.js", sourcemap: true).map
    end
  end
end
