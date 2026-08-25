# frozen_string_literal: true

module Oxc
  # A visitor that rewrites the source it walked, by recording what to do to a node and splicing the
  # original text at the end. Everything nothing touched survives byte for byte.
  #
  #     class Renamer < Oxc::MutationVisitor
  #       def visit_identifier(node)
  #         replace(node, "renamed") if node["name"] == "count"
  #       end
  #     end
  #
  #     Renamer.new.rewrite("let count = 1")  #=> "let renamed = 1"
  #
  class MutationVisitor < Visitor
    class Overlap < StandardError; end
    class Invalid < Error; end

    Edit = Data.define(
      :start, #: Integer
      :finish, #: Integer
      :text, #: String
      :order #: Integer
    )

    attr_reader :source #: String
    attr_reader :parsed #: Oxc::ParseResult

    #: (String, ?verify: bool, **untyped) -> String
    def rewrite(source, verify: true, **options)
      @source = source
      @edits = [] #: Array[Edit]
      @replaced = [] #: Array[[Integer, Integer]]
      @parsed = Oxc.parse(source, **options).validate!

      visit(parsed)

      rewritten = apply

      verify ? verified(rewritten, options) : rewritten
    end

    #: (Oxc::Node, String) -> void
    def replace(node, text)
      @replaced << [node.start, node.finish]

      edit(node.start, node.finish, text)
    end

    #: (Oxc::Node) -> void
    def remove(node)
      replace(node, "")
    end

    #: (Oxc::Node, String) -> void
    def insert_before(node, text)
      edit(node.start, node.start, text)
    end

    #: (Oxc::Node, String) -> void
    def insert_after(node, text)
      edit(node.finish, node.finish, text)
    end

    #: (Oxc::Node, String, String) -> void
    def wrap(node, before, after)
      insert_before(node, before)
      insert_after(node, after)
    end

    #: (Oxc::Node) -> void
    def visit_children(node)
      return nil if replaced?(node)

      super
    end

    private

    #: (String, Hash[Symbol, untyped]) -> String
    def verified(rewritten, options)
      answer = Oxc.parse(rewritten, **options, ast: false)

      return rewritten unless answer.errors?

      raise Invalid, "what was rewritten no longer reads as JavaScript: #{answer.errors.first&.message}"
    end

    #: (Oxc::Node) -> bool
    def replaced?(node)
      @replaced.any? { |start, finish| node.start >= start && node.finish <= finish }
    end

    #: (Integer, Integer, String) -> void
    def edit(start, finish, text)
      @edits.each do |existing|
        next unless overlaps?(existing, start, finish)

        raise Overlap, "an edit at #{start}..#{finish} overlaps one at #{existing.start}..#{existing.finish}"
      end

      @edits << Edit.new(start: start, finish: finish, text: text, order: @edits.length)

      nil
    end

    #: (Edit, Integer, Integer) -> bool
    def overlaps?(existing, start, finish)
      return false if existing.start == existing.finish && start == finish

      start < existing.finish && existing.start < finish
    end

    #: () -> String
    def apply
      taken = 0
      result = +""

      @edits.sort_by { |edit| [edit.start, edit.order] }.each do |edit|
        result << source.byteslice(taken, edit.start - taken).to_s << edit.text

        taken = edit.finish
      end

      result << source.byteslice(taken..).to_s
    end
  end
end
