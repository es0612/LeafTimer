#!/usr/bin/env ruby
# add-to-target.rb の CLI 契約をサブプロセス実行で検証する。
# xcodeproj gem 必須のため make tests / precheck のチェーンには入れない (CLAUDE.md ルール 27)。
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"

class AddToTargetTest < Minitest::Test
  BIN = File.expand_path("add-to-target.rb", __dir__)
  REAL_PROJ = File.expand_path("../LeafTimer.xcodeproj", __dir__)

  def with_tmp_proj
    Dir.mktmpdir do |dir|
      proj = File.join(dir, "LeafTimer.xcodeproj")
      FileUtils.cp_r(REAL_PROJ, proj)
      Dir.chdir(dir) { yield proj }
    end
  end

  def run_cli(*args)
    Open3.capture2e("ruby", BIN, *args)
  end

  def test_adds_new_file_to_app_target
    with_tmp_proj do |proj|
      out, status = run_cli(proj, "LeafTimer/Components/PlanFixtureDummy.swift", "LeafTimer", "LeafTimer/Components")
      assert status.success?, "expected success, got: #{out}"
      assert_includes out, "added:"
      assert_includes File.read(File.join(proj, "project.pbxproj")), "PlanFixtureDummy.swift"
    end
  end

  def test_rerun_is_idempotent_noop
    with_tmp_proj do |proj|
      _, first = run_cli(proj, "LeafTimer/Components/PlanFixtureDummy.swift", "LeafTimer", "LeafTimer/Components")
      assert first.success?
      out, second = run_cli(proj, "LeafTimer/Components/PlanFixtureDummy.swift", "LeafTimer", "LeafTimer/Components")
      assert second.success?
      assert_includes out, "no-op"
    end
  end

  def test_unknown_target_fails_red
    with_tmp_proj do |proj|
      out, status = run_cli(proj, "LeafTimer/Components/PlanFixtureDummy.swift", "NoSuchTarget", "LeafTimer/Components")
      refute status.success?, "expected failure for unknown target"
      assert_includes out, "target not found"
    end
  end

  def test_wrong_arity_fails_red
    out, status = run_cli("only-one-arg")
    refute status.success?
    assert_includes out, "usage:"
  end
end
