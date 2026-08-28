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

  # 隣接する2件の PBXBuildFile エントリを入れ替えて非正準順に乱す。
  # Issue #130 fix round 1 (I-2): 乱さずに before/after 比較を足すだけだと
  # 1回目の save で正準化されるため常に GREEN になり検証にならない。
  def perturb_canonical_order(pbxproj_path)
    lines = File.readlines(pbxproj_path)
    idx = lines.each_index.find do |i|
      lines[i] =~ /\A\t\t[0-9A-F]{24} .*isa = PBXBuildFile;/ &&
        lines[i + 1] =~ /\A\t\t[0-9A-F]{24} .*isa = PBXBuildFile;/
    end
    raise "fixture pbxproj: no adjacent PBXBuildFile lines found to perturb" unless idx
    lines[idx], lines[idx + 1] = lines[idx + 1], lines[idx]
    File.write(pbxproj_path, lines.join)
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
      # 既に app target に attach 済みの実ファイルを使い、最初から no-op 経路に入るようにする。
      pbxproj_path = File.join(proj, "project.pbxproj")
      perturb_canonical_order(pbxproj_path)
      before = File.read(pbxproj_path)

      out, status = run_cli(proj, "LeafTimer/Components/AppLogger.swift", "LeafTimer", "LeafTimer/Components")
      assert status.success?, "expected success, got: #{out}"
      assert_includes out, "no-op"

      after = File.read(pbxproj_path)
      assert_equal before, after, "no-op 経路はファイルを一切書き換えないはず (byte-for-byte 不変)"
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
