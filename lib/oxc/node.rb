# frozen_string_literal: true

module Oxc
  class Node
    include Enumerable #[Oxc::Node]

    ACRONYM = /([A-Z]+)([A-Z][a-z])/ #: Regexp
    BOUNDARY = /([a-z\d])([A-Z])/ #: Regexp
    SPAN = ["type", "start", "end"].freeze #: Array[String]
    SCALARS = 3 #: Integer

    attr_reader :attributes #: Hash[String, untyped]
    attr_reader :parent #: Oxc::Node?

    #: (Hash[String, untyped], ?Oxc::Node?) -> void
    def initialize(attributes, parent = nil)
      @attributes = attributes
      @parent = parent
    end

    #: () -> String
    def type
      attributes.fetch("type")
    end

    #: () -> Integer
    def start
      attributes.fetch("start")
    end

    #: () -> Integer
    def finish
      attributes.fetch("end")
    end

    #: () -> String
    def name
      @name ||= type.gsub(ACRONYM, '\1_\2').gsub(BOUNDARY, '\1_\2').downcase
    end

    #: (String) -> untyped
    def [](key)
      attributes[key]
    end

    #: (String) -> String?
    def slice(source)
      source.byteslice(start, finish - start)
    end

    #: () -> Array[Oxc::Node]
    def children
      @children ||= attributes.each_value
                              .flat_map { |value| value.is_a?(Array) ? value : [value] }
                              .select { |value| value.is_a?(Hash) && value.key?("type") }
                              .map { |value| Node.new(value, self) }
                              .freeze
    end

    #: () { (Oxc::Node) -> void } -> void
    #: () -> Enumerator[Oxc::Node, void]
    def each(&)
      return enum_for(:each) unless block_given?

      yield self

      children.each { |child| child.each(&) }
    end

    #: () -> Array[Oxc::Node]
    def ancestors
      parent ? [parent, *parent.ancestors] : []
    end

    #: (Integer) -> Oxc::Node?
    def at(offset)
      covering = each.select { |node| offset >= node.start && offset < node.finish }

      covering.min_by { |node| node.finish - node.start }
    end

    #: (String) -> Array[Oxc::Node]
    def every(type)
      each.select { |node| node.type == type }
    end

    #: () -> Hash[String, untyped]
    def scalars
      attributes.reject { |key, value| SPAN.include?(key) || value.nil? || value.is_a?(Hash) || value.is_a?(Array) }
    end

    #: () -> String
    def inspect
      described = scalars.first(SCALARS).map { |key, value| "#{key}=#{value.inspect}" }
      more = scalars.length > SCALARS ? " …" : ""

      "#<#{self.class.name} #{type} #{start}..#{finish}#{" #{described.join(" ")}" unless described.empty?}#{more}>"
    end

    #: (Symbol, *untyped) -> untyped
    def method_missing(name, *arguments)
      key = name.to_s

      return super unless attributes.key?(key)

      wrap(attributes[key])
    end

    #: (Symbol, ?bool) -> bool
    def respond_to_missing?(name, include_private = false)
      attributes.key?(name.to_s) || super
    end

    private

    #: (untyped) -> untyped
    def wrap(value)
      case value
      when Hash then value.key?("type") ? Node.new(value, self) : value
      when Array then value.map { |item| wrap(item) }
      else value
      end
    end
  end
end
