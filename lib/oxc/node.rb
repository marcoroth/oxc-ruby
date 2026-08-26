# frozen_string_literal: true

module Oxc
  class Node
    include Enumerable #[Oxc::Node]

    ACRONYM = /([A-Z]+)([A-Z][a-z])/ #: Regexp
    BOUNDARY = /([a-z\d])([A-Z])/ #: Regexp
    SPAN = ["type", "start", "end"].freeze #: Array[String]

    attr_reader :parent #: Oxc::Node?

    protected

    attr_reader :attributes #: Hash[String, untyped]
    attr_reader :text #: String?

    public

    #: (Hash[String, untyped], ?Oxc::Node?, ?String?) -> void
    def initialize(attributes, parent = nil, text = nil)
      @attributes = attributes
      @parent = parent
      @text = text || parent&.text
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
    def underscored_type
      @underscored_type ||= type.gsub(ACRONYM, '\1_\2').gsub(BOUNDARY, '\1_\2').downcase
    end

    #: (String) -> untyped
    def [](key)
      attributes[key]
    end

    #: (?String?) -> String?
    def slice(from = text)
      raise ArgumentError, "this node does not know its source, so #slice needs it" unless from

      from.byteslice(start, finish - start)
    end

    #: () -> Array[String]
    def keys
      attributes.keys
    end

    #: () -> Hash[String, untyped]
    def to_h
      attributes
    end

    #: (?untyped) -> String
    def to_json(state = nil)
      state ? attributes.to_json(state) : attributes.to_json
    end

    #: (Array[Symbol]?) -> Hash[Symbol, untyped]
    def deconstruct_keys(keys)
      found = {} #: Hash[Symbol, untyped]

      if keys
        keys.each do |name|
          key = field_for(name.to_s)

          found[name] = wrap(attributes[key]) if key
        end
      else
        attributes.each_key { |key| found[key.to_sym] = wrap(attributes[key]) }
      end

      found
    end

    #: () -> Array[Oxc::Node]
    def child_nodes
      @child_nodes ||= attributes.each_value
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

      child_nodes.each { |child| child.each(&) }
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
    def fields
      attributes.except(*SPAN)
    end

    #: () -> String
    def inspect
      described = fields.map { |key, value| described_field(key, value) }

      "#<#{self.class.name} #{type} range=[#{start}, #{finish}]#{" #{described.join(" ")}" unless described.empty?}>"
    end

    #: (Symbol, *untyped) -> untyped
    def method_missing(name, *arguments)
      key = field_for(name.to_s)

      return super unless key

      wrap(attributes[key])
    end

    #: (Symbol, ?bool) -> bool
    def respond_to_missing?(name, include_private = false)
      !field_for(name.to_s).nil? || super
    end

    private

    #: (String, untyped) -> String
    def described_field(key, value)
      case value
      when Array then "#{key}=#{if value.empty?
                                  "[]"
                                else
                                  "[... #{value.length} #{value.length == 1 ? "item" : "items"}]"
                                end}"
      when Hash then "#{key}=#<#{self.class.name} #{value["type"]}>"
      else "#{key}=#{value.inspect}"
      end
    end

    #: (String) -> String?
    def field_for(name)
      return name if attributes.key?(name)

      camelized = name.gsub(/_([a-z\d])/) { Regexp.last_match(1).to_s.upcase }

      camelized if attributes.key?(camelized)
    end

    #: (untyped) -> untyped
    def wrap(value)
      case value
      when Hash then value.key?("type") ? Node.new(value, self, text) : value
      when Array then value.map { |item| wrap(item) }
      else value
      end
    end
  end
end
