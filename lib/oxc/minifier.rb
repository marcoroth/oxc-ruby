# frozen_string_literal: true

module Oxc
  class Minifier
    attr_reader :options #: Hash[Symbol, untyped]

    #: (?filename: String?, ?lang: String?, ?source_type: String?, ?compress: compress?, ?mangle: mangle?, ?codegen: codegen?, ?sourcemap: bool, ?strict: bool) -> void
    def initialize(**options)
      @options = options.transform_keys(&:to_sym).freeze

      freeze
    end

    #: (String, ?filename: String?, ?lang: String?, ?source_type: String?, ?compress: compress?, ?mangle: mangle?, ?codegen: codegen?, ?sourcemap: bool, ?strict: bool) -> Oxc::MinifyResult
    def minify(source, **overrides)
      Oxc.minify(source, **options, **overrides)
    end

    alias call minify

    #: (?filename: String?, ?lang: String?, ?source_type: String?, ?compress: compress?, ?mangle: mangle?, ?codegen: codegen?, ?sourcemap: bool, ?strict: bool) -> Oxc::Minifier
    def with(**overrides)
      self.class.new(**options, **overrides)
    end

    #: () -> String
    def inspect
      "#<#{self.class.name} #{options.inspect}>"
    end
  end
end
