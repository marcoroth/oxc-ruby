# frozen_string_literal: true

require "test_helper"

class OxcTest < Minitest::Spec
  test "has a version number" do
    assert_equal "0.1.0", Oxc::VERSION
  end

  test "the native library was built from the version the gem was" do
    assert_equal Oxc::VERSION, Oxc::Backend.version
  end

  test "reports the version of oxc it was compiled against" do
    assert_equal "0.147.0", Oxc.oxc_version
  end

  test "the version it reports is the one Cargo.lock pins" do
    locked = File.read(File.expand_path("../rust/Cargo.lock", __dir__))[/name = "oxc"\nversion = "([^"]+)"/, 1]

    assert_equal locked, Oxc.oxc_version
  end
end
