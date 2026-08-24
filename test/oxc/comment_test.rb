# frozen_string_literal: true

require "test_helper"

module Oxc
  class CommentTest < Minitest::Spec
    SOURCE = "// café\nfoo()"

    def comment
      Oxc.parse(SOURCE).comments.first
    end

    test "counts in UTF-8 bytes, which is what oxc counts in" do
      assert_equal 14, SOURCE.bytesize
      assert_equal 13, SOURCE.length

      assert_equal 0, comment.start
      assert_equal 8, comment.finish
    end

    test "reads its span back out of the source it came from" do
      assert_equal "// café", comment.slice(SOURCE)
    end

    test "carries what it said without the marks around it" do
      assert_equal " café", comment.value
    end

    test "prints what it is" do
      ascii = Oxc.parse("// hi\nfoo()").comments.first

      assert_equal %(#<Oxc::Comment Line " hi">), ascii.inspect
    end

    test "keeps what it read to itself" do
      assert_predicate comment, :frozen?
    end
  end
end
