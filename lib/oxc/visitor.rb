# frozen_string_literal: true

module Oxc
  class Visitor
    #: (Oxc::Node | Oxc::ParseResult) -> void
    def visit(node)
      node = node.root if node.is_a?(ParseResult)

      return nil unless node

      answer = "visit_#{node.name}"

      respond_to?(answer) ? public_send(answer, node) : visit_children(node)

      nil
    end

    #: (Oxc::Node) -> void
    def visit_children(node)
      node.children.each { |child| visit(child) }

      nil
    end
  end
end
