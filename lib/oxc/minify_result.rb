# frozen_string_literal: true

module Oxc
  class MinifyResult < Result
    #: (String) -> Oxc::MinifyResult
    def self.from_json(payload)
      parsed = JSON.parse(payload)

      new(
        code: parsed.fetch("code"),
        map: parsed["map"],
        legal_comments: parsed.fetch("legal_comments"),
        diagnostics: parsed.fetch("errors").map { |diagnostic| Diagnostic.from_hash(diagnostic) },
        panicked: parsed.fetch("panicked")
      )
    end

    #: (code: String, diagnostics: Array[Oxc::Diagnostic], ?map: String?, ?legal_comments: Array[String], ?panicked: bool) -> void
    def initialize(...)
      super

      freeze
    end
  end
end
