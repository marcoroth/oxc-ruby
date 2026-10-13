# frozen_string_literal: true

module Oxc
  class Visitor
    #: (Oxc::Node | Oxc::ParseResult) -> void
    def visit(node)
      node = node.root if node.is_a?(ParseResult)

      return nil unless node

      method_name = "visit_#{node.underscored_type}"

      respond_to?(method_name) ? public_send(method_name, node) : visit_children(node)

      nil
    end

    #: (Oxc::Node) -> void
    def visit_children(node)
      node.child_nodes.each { |child| visit(child) }

      nil
    end
  end
end
