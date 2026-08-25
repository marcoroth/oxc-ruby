# frozen_string_literal: true

require "mkmf"
require "fileutils"

ext_dir = __dir__
root_dir = File.expand_path("../..", ext_dir)

rust_dir = File.join(root_dir, "rust")

unless File.exist?(File.join(rust_dir, "Cargo.toml"))
  abort <<~MESSAGE

    ERROR: Rust sources not found at #{rust_dir}.

  MESSAGE
end

unless system("cargo --version > /dev/null 2>&1")
  abort <<~MESSAGE

    ERROR: Rust toolchain not found.

    oxc requires the Rust toolchain to compile from source.

    Install Rust: https://rustup.rs

  MESSAGE
end

RUST_TARGETS = {
  "aarch64-linux-gnu" => "aarch64-unknown-linux-gnu",
  "aarch64-linux-musl" => "aarch64-unknown-linux-musl",
  "arm-linux-gnu" => "armv7-unknown-linux-gnueabihf",
  "arm-linux-musl" => "armv7-unknown-linux-musleabihf",
  "arm64-darwin" => "aarch64-apple-darwin",
  "x86_64-darwin" => "x86_64-apple-darwin",
  "x86_64-linux-gnu" => "x86_64-unknown-linux-gnu",
  "x86_64-linux-musl" => "x86_64-unknown-linux-musl",
  "x86-linux-gnu" => "i686-unknown-linux-gnu",
  "x86-linux-musl" => "i686-unknown-linux-musl",
}.freeze

cross_compiling = ENV.key?("RUBY_CC_VERSION")
target_platform = ENV.fetch("CARGO_BUILD_TARGET", nil)

if cross_compiling && target_platform.nil?
  rcd_platform = ENV.fetch("RCD_PLATFORM", "")
  target_platform = RUST_TARGETS[rcd_platform]

  if target_platform.nil?
    ruby_platform = RbConfig::CONFIG["arch"]
    target_platform = RUST_TARGETS.values.find { |target| ruby_platform.include?(target.split("-").first) }
  end
end

header_path = File.join(ext_dir, "include", "oxc.h")

FileUtils.mkdir_p(File.dirname(header_path))

target_dir = File.join(rust_dir, "target")

if target_platform
  puts "oxc: Cross-compiling Rust for target: #{target_platform}"

  system("rustup target add #{target_platform}") || warn("oxc: Failed to add Rust target #{target_platform}")

  cargo_args = "--release --locked --target #{target_platform}"
  lib_dir = File.join(target_dir, target_platform, "release")
else
  puts "oxc: Compiling Rust library for native platform..."

  cargo_args = "--release --locked"
  lib_dir = File.join(target_dir, "release")
end

unless system("cd #{rust_dir} && cargo build #{cargo_args}")
  abort "ERROR: Failed to compile oxc from Rust source."
end

unless File.exist?(header_path)
  abort "ERROR: cbindgen did not generate #{header_path}. Try `cargo clean` in #{rust_dir} and reinstall."
end

static_lib = File.join(lib_dir, "liboxc_ffi.a")

developing = File.exist?(File.join(root_dir, ".git"))

if File.exist?(static_lib) && !developing
  vendored = File.join(ext_dir, "liboxc_ffi.a")

  FileUtils.cp(static_lib, vendored)
  FileUtils.rm_rf(target_dir)

  puts "oxc: Static library vendored at #{vendored}, Rust build directory removed"

  $LDFLAGS << " #{vendored}"
elsif File.exist?(static_lib)
  puts "oxc: Static library found at #{static_lib}"

  $LDFLAGS << " #{static_lib}"
else
  host_os = target_platform || RbConfig::CONFIG["host_os"]

  lib_name = case host_os
             when /darwin/ then "liboxc_ffi.dylib"
             when /mingw|mswin|windows/ then "oxc_ffi.dll"
             else "liboxc_ffi.so"
             end

  lib_path = File.join(lib_dir, lib_name)

  abort "ERROR: Shared library not found at #{lib_path}" unless File.exist?(lib_path)

  puts "oxc: Shared library found at #{lib_path} (dynamic)"

  $LDFLAGS << " -L#{lib_dir} -loxc_ffi"
  $LDFLAGS << " -Wl,-rpath,#{lib_dir}" if RbConfig::CONFIG["host_os"].match?(/darwin|linux/)
end

$CFLAGS << " -I#{ext_dir}"

create_makefile("oxc/oxc")
