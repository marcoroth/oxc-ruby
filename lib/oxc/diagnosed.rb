# frozen_string_literal: true

module Oxc
  # @rbs module-self _Diagnosed
  module Diagnosed
    # @rbs @panicked: bool

    #: () -> Array[Oxc::Diagnostic]
    def errors
      diagnostics.select(&:error?)
    end

    #: () -> Array[Oxc::Diagnostic]
    def warnings
      diagnostics.select(&:warning?)
    end

    #: () -> bool
    def errors?
      !errors.empty?
    end

    #: () -> bool
    def warnings?
      !warnings.empty?
    end

    #: () -> bool
    def panicked?
      @panicked
    end
  end
end
