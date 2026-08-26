# frozen_string_literal: true

module Oxc
  class Diagnostic
    ERROR = "error" #: String
    WARNING = "warning" #: String

    attr_reader :severity #: String
    attr_reader :message #: String
    attr_reader :labels #: Array[Oxc::Label]
    attr_reader :help #: String?
    attr_reader :codeframe #: String?

    #: (Hash[String, untyped]) -> Oxc::Diagnostic
    def self.from_hash(parsed)
      new(
        severity: parsed.fetch("severity"),
        message: parsed.fetch("message"),
        labels: parsed.fetch("labels").map { |label| Label.from_hash(label) },
        help: parsed["help"],
        codeframe: parsed["codeframe"]
      )
    end

    #: (severity: String, message: String, labels: Array[Oxc::Label], ?help: String?, ?codeframe: String?) -> void
    def initialize(severity:, message:, labels:, help: nil, codeframe: nil)
      @severity = severity
      @message = message
      @labels = labels.freeze
      @help = help
      @codeframe = codeframe

      freeze
    end

    #: () -> bool
    def error?
      severity == ERROR
    end

    #: () -> bool
    def warning?
      severity == WARNING
    end

    #: () -> String
    def to_s
      message
    end

    #: () -> String
    def inspect
      "#<#{self.class.name} #{severity} #{message.inspect}>"
    end
  end

  class Label
    attr_reader :message #: String?
    attr_reader :start #: Integer
    attr_reader :finish #: Integer

    #: (Hash[String, untyped]) -> Oxc::Label
    def self.from_hash(parsed)
      new(message: parsed["message"], start: parsed.fetch("start"), finish: parsed.fetch("end"))
    end

    #: (start: Integer, finish: Integer, ?message: String?) -> void
    def initialize(start:, finish:, message: nil)
      @start = start
      @finish = finish
      @message = message

      freeze
    end

    #: (String) -> String?
    def slice(source)
      source.byteslice(start, finish - start)
    end

    #: () -> String
    def inspect
      "#<#{self.class.name} range=[#{start}, #{finish}]#{" #{message.inspect}" if message}>"
    end
  end
end
