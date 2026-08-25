# frozen_string_literal: true

module Oxc
  class Result
    include Diagnosed

    attr_reader :code #: String
    attr_reader :map #: String?
    attr_reader :legal_comments #: Array[String]
    attr_reader :diagnostics #: Array[Oxc::Diagnostic]

    #: (code: String, diagnostics: Array[Oxc::Diagnostic], ?map: String?, ?legal_comments: Array[String], ?panicked: bool) -> void
    def initialize(code:, diagnostics:, map: nil, legal_comments: [], panicked: false)
      @code = code
      @map = map
      @legal_comments = legal_comments.freeze
      @diagnostics = diagnostics.freeze
      @panicked = panicked
    end

    #: (?strict: bool?) -> self
    def validate!(strict: false)
      return self unless errors? || panicked?
      return self unless strict || panicked? || code.empty?

      raise SyntaxError.new(errors.first&.message || "oxc could not read the source", self)
    end

    #: () -> String
    def to_s
      code
    end

    #: () -> String
    def inspect
      "#<#{self.class.name} #{parts.join(" ")}>"
    end

    private

    #: () -> Array[String]
    def parts
      parts = ["code=#{code.inspect}"] #: Array[String]
      parts << "map=#{map.length} bytes" if map
      parts << "legal_comments=#{legal_comments.inspect}" unless legal_comments.empty?
      parts << "diagnostics=#{diagnostics.length}" unless diagnostics.empty?

      parts
    end
  end
end
