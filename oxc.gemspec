# frozen_string_literal: true

require_relative "lib/oxc/version"

Gem::Specification.new do |spec|
  spec.name = "oxc"
  spec.version = Oxc::VERSION
  spec.authors = ["Marco Roth"]
  spec.email = ["marco.roth@intergga.ch"]

  spec.summary = "A collection of high-performance tools for JavaScript and TypeScript written in Rust."
  spec.description = "Ruby bindings for Oxc, the JavaScript Oxidation Compiler. A collection of high-performance tools for JavaScript and TypeScript written in Rust."
  spec.homepage = "https://github.com/marcoroth/oxc-ruby"
  spec.licenses = ["MIT", "Apache-2.0"]
  spec.required_ruby_version = ">= 3.2.0"
  spec.require_paths = ["lib"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/marcoroth/oxc-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/marcoroth/oxc-ruby/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "oxc.gemspec",
    "LICENSE.txt",
    "licenses/*.txt",
    "licenses/README.md",
    "README.md",
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "ext/oxc/extconf.rb",
    "ext/oxc/oxc.c",
    "ext/oxc/include/**/*.h",
    "rust/Cargo.toml",
    "rust/Cargo.lock",
    "rust/build.rs",
    "rust/cbindgen.toml",
    "rust/rustfmt.toml",
    "rust/src/**/*.rs"
  ]

  spec.extensions = ["ext/oxc/extconf.rb"]
end
