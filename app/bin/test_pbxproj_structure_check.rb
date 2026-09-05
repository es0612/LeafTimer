#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in pbxproj_structure_check.rb.
# Run: ruby bin/test_pbxproj_structure_check.rb
require 'minitest/autorun'
require 'set'
require_relative 'pbxproj_structure_check'

class PbxprojStructureCheckTest < Minitest::Test
  PBXPROJ = <<~PBX
    // !$*UTF8*$!
    {
    	objects = {
    		3857B9BA24A77C1B00B21CCD /* ViewInspector in Frameworks */ = {isa = PBXBuildFile; productRef = 3857B9B924A77C1B00B21CCD /* ViewInspector */; };
    		3857B9B624A7734300B21CCD /* App */ = {
    			isa = PBXGroup;
    			children = (
    				3857B9B424A7725000B21CCD /* Assets.xcassets */,
    			);
    		};
    	};
    	rootObject = 3857B9A824A7725000B21CCD /* Project object */;
    }
  PBX

  # --- referenced_uuids ---------------------------------------------------

  def test_referenced_uuids_collects_every_24_hex_token
    got = PbxprojStructureCheck.referenced_uuids(PBXPROJ)
    assert_equal Set['3857B9BA24A77C1B00B21CCD', '3857B9B924A77C1B00B21CCD',
                     '3857B9B624A7734300B21CCD', '3857B9B424A7725000B21CCD',
                     '3857B9A824A7725000B21CCD'], got
  end

  # 23 桁や小文字 hex は UUID ではない (SHA 等の誤検出を防ぐ)
  def test_referenced_uuids_ignores_non_uuid_hex
    text = "deadbeefdeadbeefdeadbeef 3857B9A824A7725000B21CC 3857B9A824A7725000B21CCDEF"
    assert_empty PbxprojStructureCheck.referenced_uuids(text)
  end

  # --- report -------------------------------------------------------------

  def test_report_ok_when_every_reference_is_defined
    r = PbxprojStructureCheck.report(
      defined_uuids: Set['A' * 24, 'B' * 24],
      referenced_uuids: Set['A' * 24, 'B' * 24],
      target_uuids: ['A' * 24],
      target_attribute_keys: ['A' * 24]
    )
    assert r[:ok]
    assert_empty r[:dangling]
    assert_empty r[:orphan_target_attrs]
  end

  def test_report_flags_dangling_reference
    r = PbxprojStructureCheck.report(
      defined_uuids: Set['A' * 24],
      referenced_uuids: Set['A' * 24, 'D' * 24],
      target_uuids: ['A' * 24],
      target_attribute_keys: []
    )
    refute r[:ok]
    assert_equal ['D' * 24], r[:dangling]
  end

  # PR #140 で実測: target.remove_from_project は TargetAttributes を連鎖削除しない
  def test_report_flags_orphan_target_attributes
    r = PbxprojStructureCheck.report(
      defined_uuids: Set['A' * 24, 'B' * 24],
      referenced_uuids: Set['A' * 24, 'B' * 24],
      target_uuids: ['A' * 24],
      target_attribute_keys: ['A' * 24, 'B' * 24]
    )
    refute r[:ok]
    assert_equal ['B' * 24], r[:orphan_target_attrs]
  end

  def test_report_results_are_sorted_for_stable_output
    r = PbxprojStructureCheck.report(
      defined_uuids: Set[],
      referenced_uuids: Set['F' * 24, 'C' * 24],
      target_uuids: [],
      target_attribute_keys: ['E' * 24, 'D' * 24]
    )
    assert_equal ['C' * 24, 'F' * 24], r[:dangling]
    assert_equal ['D' * 24, 'E' * 24], r[:orphan_target_attrs]
  end
end
