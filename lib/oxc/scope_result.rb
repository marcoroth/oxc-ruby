# frozen_string_literal: true

module Oxc
  class ScopeResult < Result
    attr_reader :renamed #: Hash[String, String]

    #: (String) -> Oxc::ScopeResult
    def self.from_json(payload)
      parsed = JSON.parse(payload)

      new(
        code: parsed.fetch("code"),
        map: parsed["map"],
        renamed: parsed.fetch("renamed"),
        diagnostics: parsed.fetch("errors").map { |diagnostic| Diagnostic.from_hash(diagnostic) },
        panicked: parsed.fetch("panicked")
      )
    end

    #: (code: String, diagnostics: Array[Oxc::Diagnostic], ?map: String?, ?renamed: Hash[String, String], ?legal_comments: Array[String], ?panicked: bool) -> void
    def initialize(renamed: {}, **)
      super(**)

      @renamed = renamed.freeze

      freeze
    end

    private

    #: () -> Array[String]
    def parts
      parts = super
      parts << "renamed=#{renamed.length}" unless renamed.empty?

      parts
    end
  end
end
