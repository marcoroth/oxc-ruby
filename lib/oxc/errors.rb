# frozen_string_literal: true

module Oxc
  class Error < StandardError; end
  class OptionError < Error; end
  class EncodingError < Error; end
  class TransformError < Error; end
  class InternalError < Error; end
  class PanicError < InternalError; end

  class SyntaxError < Error
    attr_reader :result #: (Oxc::Result | Oxc::ParseResult)?

    #: (String, ?(Oxc::Result | Oxc::ParseResult)?) -> void
    def initialize(message, result = nil)
      super(message)

      @result = result
    end

    #: () -> Array[Oxc::Diagnostic]
    def diagnostics
      result ? result.diagnostics : []
    end
  end
end
