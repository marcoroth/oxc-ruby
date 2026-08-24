# frozen_string_literal: true

module Oxc
  class TransformResult < Result
    attr_reader :declaration #: String?
    attr_reader :declaration_map #: String?
    attr_reader :helpers_used #: Hash[String, String]

    #: (String) -> Oxc::TransformResult
    def self.from_json(payload)
      parsed = JSON.parse(payload)

      new(
        code: parsed.fetch("code"),
        map: parsed["map"],
        declaration: parsed["declaration"],
        declaration_map: parsed["declaration_map"],
        legal_comments: parsed.fetch("legal_comments"),
        helpers_used: parsed.fetch("helpers_used"),
        diagnostics: parsed.fetch("errors").map { |diagnostic| Diagnostic.from_hash(diagnostic) },
        panicked: parsed.fetch("panicked")
      )
    end

    #: (code: String, diagnostics: Array[Oxc::Diagnostic], ?map: String?, ?declaration: String?, ?declaration_map: String?, ?legal_comments: Array[String], ?helpers_used: Hash[String, String], ?panicked: bool) -> void
    def initialize(declaration: nil, declaration_map: nil, helpers_used: {}, **)
      super(**)

      @declaration = declaration
      @declaration_map = declaration_map
      @helpers_used = helpers_used.freeze

      freeze
    end

    private

    #: () -> Array[String]
    def parts
      parts = super
      parts << "declaration=#{declaration.length} bytes" if declaration
      parts << "helpers_used=#{helpers_used.length}" unless helpers_used.empty?

      parts
    end
  end
end
