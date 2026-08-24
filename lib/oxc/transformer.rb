# frozen_string_literal: true

module Oxc
  class Transformer
    attr_reader :options #: Hash[Symbol, untyped]

    #: (?filename: String?, ?lang: String?, ?source_type: String?, ?cwd: String?, ?target: targets?, ?jsx: jsx?, ?typescript: typescript?, ?assumptions: assumptions?, ?decorator: decorator?, ?helpers: helpers?, ?define: Hash[String, String]?, ?inject: inject?, ?minify: minify?, ?codegen: codegen?, ?sourcemap: bool, ?strict: bool) -> void
    def initialize(**options)
      @options = options.transform_keys(&:to_sym).freeze

      freeze
    end

    #: (String, ?filename: String?, ?lang: String?, ?source_type: String?, ?cwd: String?, ?target: targets?, ?jsx: jsx?, ?typescript: typescript?, ?assumptions: assumptions?, ?decorator: decorator?, ?helpers: helpers?, ?define: Hash[String, String]?, ?inject: inject?, ?minify: minify?, ?codegen: codegen?, ?sourcemap: bool, ?strict: bool) -> Oxc::TransformResult
    def transform(source, **overrides)
      Oxc.transform(source, **options, **overrides)
    end

    alias call transform

    #: (?filename: String?, ?lang: String?, ?source_type: String?, ?cwd: String?, ?target: targets?, ?jsx: jsx?, ?typescript: typescript?, ?assumptions: assumptions?, ?decorator: decorator?, ?helpers: helpers?, ?define: Hash[String, String]?, ?inject: inject?, ?minify: minify?, ?codegen: codegen?, ?sourcemap: bool, ?strict: bool) -> Oxc::Transformer
    def with(**overrides)
      self.class.new(**options, **overrides)
    end

    #: () -> String
    def inspect
      "#<#{self.class.name} #{options.inspect}>"
    end
  end
end
