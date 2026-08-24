# frozen_string_literal: true

module Oxc
  module Backend
    module Unavailable
      #: (String, String) -> String
      def minify(_source, _options_json)
        unavailable(__method__)
      end

      #: (String, String) -> String
      def transform(_source, _options_json)
        unavailable(__method__)
      end

      #: (String, String) -> String
      def parse(_source, _options_json)
        unavailable(__method__)
      end

      #: () -> String
      def version
        unavailable(__method__)
      end

      #: () -> String
      def oxc_version
        unavailable(__method__)
      end

      private

      #: (Symbol?) -> bot
      def unavailable(name)
        raise NotImplementedError, "Oxc::Backend.#{name} is defined by the native extension, which did not load"
      end
    end

    extend Unavailable
  end
end
