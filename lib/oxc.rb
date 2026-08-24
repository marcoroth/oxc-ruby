# frozen_string_literal: true

require "json"

require_relative "oxc/version"
require_relative "oxc/errors"
require_relative "oxc/backend"

begin
  major, minor, = RUBY_VERSION.split(".")
  require_relative "oxc/#{major}.#{minor}/oxc"
rescue LoadError
  require_relative "oxc/oxc"
end

require_relative "oxc/options"
require_relative "oxc/diagnostic"
require_relative "oxc/diagnosed"
require_relative "oxc/result"
require_relative "oxc/minify_result"
require_relative "oxc/transform_result"
require_relative "oxc/parse_result"
require_relative "oxc/transformer"
require_relative "oxc/minifier"

module Oxc
  #: (String, ?filename: String?, ?lang: String?, ?source_type: String?, ?compress: compress?, ?mangle: mangle?, ?codegen: codegen?, ?sourcemap: bool, ?strict: bool) -> Oxc::MinifyResult
  def self.minify(source, **options)
    serialized = Options.serialize(options, Options::MINIFY, "minify")

    MinifyResult.from_json(Backend.minify(source.to_s, serialized)).validate!(strict: options[:strict])
  end

  #: (String, ?filename: String?, ?lang: String?, ?source_type: String?, ?cwd: String?, ?target: targets?, ?jsx: jsx?, ?typescript: typescript?, ?assumptions: assumptions?, ?decorator: decorator?, ?helpers: helpers?, ?define: Hash[String, String]?, ?inject: inject?, ?minify: minify?, ?codegen: codegen?, ?sourcemap: bool, ?strict: bool) -> Oxc::TransformResult
  def self.transform(source, **options)
    serialized = Options.serialize(options, Options::TRANSFORM, "transform")

    TransformResult.from_json(Backend.transform(source.to_s, serialized)).validate!(strict: options[:strict])
  end

  #: (String, ?filename: String?, ?lang: String?, ?source_type: String?, ?ast_type: String?, ?ast: bool, ?ranges: bool, ?preserve_parens: bool, ?comments: bool, ?module_record: bool, ?symbols: bool, ?semantic_errors: bool) -> Oxc::ParseResult
  def self.parse(source, **options)
    serialized = Options.serialize(options, Options::PARSE, "parse")

    ParseResult.from_json(Backend.parse(source.to_s, serialized))
  end

  #: () -> String
  def self.oxc_version
    Backend.oxc_version
  end
end
