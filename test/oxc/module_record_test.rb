# frozen_string_literal: true

require "test_helper"

module Oxc
  class ModuleRecordTest < Minitest::Spec
    SOURCE = 'import { a } from "./a"; import def from "./b"; import * as ns from "./c"; ' \
             'export const x = 1; export { a }; export * from "./d"; import("./e"); import.meta.url'

    def record(source = SOURCE, **)
      Oxc.parse(source, source_type: "module", module_record: true, **).module_record
    end

    test "reads nothing about the module unless it was asked to" do
      assert_nil Oxc.parse(SOURCE, source_type: "module").module_record
    end

    test "knows the file has module syntax" do
      assert record["has_module_syntax"]
      refute record("foo()")["has_module_syntax"]
    end

    test "names every module the file imported, in the order it imported them" do
      requests = record["static_imports"].map { |import| import["module_request"]["value"] }

      assert_equal ["./a", "./b", "./c"], requests
    end

    test "reads a named import" do
      entry = record["static_imports"].first["entries"].first

      assert_equal "name", entry["import_name"]["kind"]
      assert_equal "a", entry["import_name"]["name"]
      assert_equal "a", entry["local_name"]["value"]
      refute entry["is_type"]
    end

    test "reads a default import" do
      assert_equal "default", record["static_imports"][1]["entries"].first["import_name"]["kind"]
    end

    test "reads a namespace import" do
      assert_equal "namespace_object", record["static_imports"][2]["entries"].first["import_name"]["kind"]
    end

    test "says which of a TypeScript file's imports carried only a type" do
      entries = record('import { type T, a } from "./a"', lang: "ts")["static_imports"].first["entries"]

      assert_equal([["T", true], ["a", false]], entries.map { |entry| [entry["local_name"]["value"], entry["is_type"]] })
    end

    test "reads what the file exported" do
      names = record["static_exports"].map { |export| export["entries"].map { |entry| entry["export_name"]["name"] } }

      assert_equal [["a"], ["x"], [nil]], names
    end

    test "reads a star export and the module it came from" do
      entry = record["static_exports"].last["entries"].first

      assert_equal "all_but_default", entry["import_name"]["kind"]
      assert_equal "./d", entry["module_request"]["value"]
    end

    test "reads where a dynamic import was written" do
      dynamic = record["dynamic_imports"]

      assert_equal 1, dynamic.length
      request = dynamic.first["module_request"]

      assert_equal %("./e"), SOURCE.byteslice(request["start"], request["end"] - request["start"])
    end

    test "reads where import.meta was written" do
      meta = record["import_metas"].first

      assert_equal "import.meta", SOURCE.byteslice(meta["start"], meta["end"] - meta["start"])
    end
  end
end
