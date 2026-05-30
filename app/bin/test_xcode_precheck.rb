#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in xcode_precheck.rb.
# Run: ruby bin/test_xcode_precheck.rb
require 'minitest/autorun'
require_relative 'xcode_precheck'

class XcodePrecheckTest < Minitest::Test
  # --- destination_name -----------------------------------------------------

  def test_destination_name_extracts_simulator_name_from_makefile
    makefile = <<~MAKE
      unit-tests:
      \t@/usr/bin/time xcodebuild \\
      \t-scheme "LeafTimer" \\
      \t-destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \\
      \tbuild test
    MAKE
    assert_equal 'iPhone 17', XcodePrecheck.destination_name(makefile)
  end

  def test_destination_name_returns_nil_when_no_destination
    assert_nil XcodePrecheck.destination_name("build:\n\techo hi\n")
  end

  # --- device_names (simctl parsing) ---------------------------------------

  def test_device_names_handles_parentheses_in_device_name
    list = <<~LIST
      == Devices ==
      -- iOS 26.0 --
          iPhone 17 (0C3FB418-AAE9-4F7E-94DE-7FCB3E145D9F) (Shutdown)
          iPhone SE (3rd generation) (1A567ABA-E309-4196-9705-E7A222D3DC99) (Booted)
          iPad Pro 11-inch (650D1AEE-D003-4694-8C13-AF3F7F2EF2EB) (Shutdown)
    LIST
    assert_equal ['iPhone 17', 'iPhone SE (3rd generation)', 'iPad Pro 11-inch'],
                 XcodePrecheck.device_names(list)
  end

  # --- simulator_available? -------------------------------------------------

  def test_simulator_available_requires_exact_name_not_prefix
    list = <<~LIST
          iPhone 17 Pro (0133C337-A7F4-455E-A0D2-DB4C62390888) (Booted)
    LIST
    # "iPhone 17" must NOT match "iPhone 17 Pro"
    refute XcodePrecheck.simulator_available?('iPhone 17', list)
    assert XcodePrecheck.simulator_available?('iPhone 17 Pro', list)
  end

  # --- iphone_suggestions ---------------------------------------------------

  def test_iphone_suggestions_unique_sorted_iphone_only
    list = <<~LIST
          iPhone 17 (0C3FB418-AAE9-4F7E-94DE-7FCB3E145D9F) (Shutdown)
          iPhone 17 (111D78BE-534A-4791-B302-8911FAEDF0D2) (Shutdown)
          iPhone SE (3rd generation) (1A567ABA-E309-4196-9705-E7A222D3DC99) (Booted)
          iPad Pro 11-inch (650D1AEE-D003-4694-8C13-AF3F7F2EF2EB) (Shutdown)
    LIST
    assert_equal ['iPhone 17', 'iPhone SE (3rd generation)'],
                 XcodePrecheck.iphone_suggestions(list)
  end

  # --- orphan_report --------------------------------------------------------

  def test_orphan_report_new_orphans_exclude_baseline
    disk     = ['A.swift', 'B.swift', 'C.swift', 'D.swift']
    attached = ['A.swift']
    baseline = ['B.swift'] # grandfathered
    r = XcodePrecheck.orphan_report(disk, attached, baseline)
    assert_equal ['B.swift', 'C.swift', 'D.swift'], r[:all_orphans].sort
    # B is grandfathered, only C and D are NEW orphans that should fail the gate
    assert_equal ['C.swift', 'D.swift'], r[:new_orphans].sort
  end

  def test_orphan_report_resolved_lists_stale_baseline_entries
    disk     = ['A.swift']
    attached = ['A.swift'] # A is now attached, no longer orphan
    baseline = ['A.swift', 'Z.swift'] # A resolved; Z no longer on disk
    r = XcodePrecheck.orphan_report(disk, attached, baseline)
    assert_equal [], r[:all_orphans]
    assert_equal [], r[:new_orphans]
    assert_equal ['A.swift', 'Z.swift'], r[:resolved].sort
  end
end
