# frozen_string_literal: true

module Oxc
  class Options
    MINIFY = [
      :filename,
      :lang,
      :source_type,
      :compress,
      :mangle,
      :codegen,
      :sourcemap,
      :strict
    ].freeze #: Array[Symbol]

    TRANSFORM = [
      :filename,
      :lang,
      :source_type,
      :cwd,
      :target,
      :jsx,
      :typescript,
      :assumptions,
      :decorator,
      :helpers,
      :define,
      :inject,
      :minify,
      :codegen,
      :sourcemap,
      :strict
    ].freeze #: Array[Symbol]

    PARSE = [
      :filename,
      :lang,
      :source_type,
      :ast_type,
      :ast,
      :ranges,
      :preserve_parens,
      :comments,
      :module_record,
      :symbols,
      :semantic_errors
    ].freeze #: Array[Symbol]

    SCOPE = [
      :filename,
      :lang,
      :source_type,
      :scope,
      :separator,
      :codegen,
      :sourcemap,
      :strict
    ].freeze #: Array[Symbol]

    KNOWN = (MINIFY | TRANSFORM | PARSE | SCOPE).freeze #: Array[Symbol]
    RUBY_ONLY = [:strict].freeze #: Array[Symbol]

    # TODO: support mangle_props. It needs `lazy-regex` and `rustc-hash` as direct dependencies of the
    # Rust crate, because `oxc_minifier::ManglePropertiesOptions` types `include` and `exclude` as
    # `lazy_regex::Regex` and `reserved` as `FxHashSet<CompactStr>`.
    UNSUPPORTED = [:mangle_props].freeze #: Array[Symbol]

    attr_reader :to_h #: Hash[Symbol, untyped]

    #: (Hash[Symbol, untyped], ?Array[Symbol], ?String) -> String
    def self.serialize(options, allowed = KNOWN, subject = "a call")
      new(options, allowed, subject).to_json
    end

    #: (Hash[Symbol, untyped], ?Array[Symbol], ?String) -> void
    def initialize(options, allowed = KNOWN, subject = "a call")
      given = options.transform_keys(&:to_sym)

      validate!(given.keys, allowed, subject)

      @to_h = normalize(given).freeze

      freeze
    end

    #: (?untyped) -> String
    def to_json(state = nil)
      JSON.generate(to_h, state)
    end

    #: () -> String
    def inspect
      "#<#{self.class.name} #{to_h.inspect}>"
    end

    private

    #: (Array[Symbol], Array[Symbol], String) -> void
    def validate!(names, allowed, subject)
      unsupported = names & UNSUPPORTED

      raise OptionError, "#{unsupported.join(", ")} is not supported yet" if unsupported.any?

      unknown = names - KNOWN

      raise OptionError, "Unknown option#{"s" if unknown.length > 1}: #{unknown.join(", ")}" if unknown.any?

      unsupported = names - allowed

      return if unsupported.empty?

      raise OptionError, "#{unsupported.join(", ")} #{unsupported.one? ? "is not an option" : "are not options"} for #{subject}"
    end

    #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
    def normalize(options)
      normalized = options.dup

      RUBY_ONLY.each { |name| normalized.delete(name) }

      normalized.compact
    end
  end
end
