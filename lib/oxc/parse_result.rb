# frozen_string_literal: true

module Oxc
  class ParseResult
    include Diagnosed

    attr_reader :program #: Hash[String, untyped]?
    attr_reader :module_record #: Hash[String, untyped]?
    attr_reader :symbols #: Hash[String, untyped]?
    attr_reader :comments #: Array[Oxc::Comment]
    attr_reader :diagnostics #: Array[Oxc::Diagnostic]

    #: (String) -> Oxc::ParseResult
    def self.from_json(payload)
      parsed = JSON.parse(payload)

      new(
        program: parsed["program"],
        module_record: parsed["module_record"],
        symbols: parsed["symbols"],
        comments: parsed.fetch("comments").map { |comment| Comment.from_hash(comment) },
        diagnostics: parsed.fetch("errors").map { |diagnostic| Diagnostic.from_hash(diagnostic) },
        panicked: parsed.fetch("panicked")
      )
    end

    #: (comments: Array[Oxc::Comment], diagnostics: Array[Oxc::Diagnostic], ?program: Hash[String, untyped]?, ?module_record: Hash[String, untyped]?, ?symbols: Hash[String, untyped]?, ?panicked: bool) -> void
    def initialize(comments:, diagnostics:, program: nil, module_record: nil, symbols: nil, panicked: false)
      @program = program.freeze
      @module_record = module_record.freeze
      @symbols = symbols.freeze
      @comments = comments.freeze
      @diagnostics = diagnostics.freeze
      @panicked = panicked

      freeze
    end

    #: () -> Oxc::Node?
    def root
      program ? Node.new(program) : nil
    end

    #: () -> Oxc::ParseResult
    def validate!
      return self unless errors? || panicked?

      raise SyntaxError.new(errors.first&.message || "oxc could not read the source", self)
    end

    #: () -> String
    def inspect
      parts = [] #: Array[String]
      parts << "#{root&.type} #{root&.start}..#{root&.finish}" if program
      parts << "module_record" if module_record
      parts << "symbols=#{symbols.fetch("declared").length}" if symbols
      parts << "comments=#{comments.length}" unless comments.empty?
      parts << "diagnostics=#{diagnostics.length}" unless diagnostics.empty?

      "#<#{self.class.name}#{" #{parts.join(" ")}" unless parts.empty?}>"
    end
  end

  class Comment
    LINE = "Line" #: String
    BLOCK = "Block" #: String

    attr_reader :type #: String
    attr_reader :value #: String
    attr_reader :start #: Integer
    attr_reader :finish #: Integer

    #: (Hash[String, untyped]) -> Oxc::Comment
    def self.from_hash(parsed)
      new(
        type: parsed.fetch("type"),
        value: parsed.fetch("value"),
        start: parsed.fetch("start"),
        finish: parsed.fetch("end")
      )
    end

    #: (type: String, value: String, start: Integer, finish: Integer) -> void
    def initialize(type:, value:, start:, finish:)
      @type = type
      @value = value
      @start = start
      @finish = finish

      freeze
    end

    #: () -> bool
    def line?
      type == LINE
    end

    #: () -> bool
    def block?
      type == BLOCK
    end

    #: (String) -> String?
    def slice(source)
      source.byteslice(start, finish - start)
    end

    #: () -> String
    def inspect
      "#<#{self.class.name} #{type} #{value.inspect}>"
    end
  end
end
