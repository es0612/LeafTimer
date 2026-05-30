# frozen_string_literal: true

# Pure helpers for xcode-precheck. Kept free of I/O so they can be unit-tested
# (see test_xcode_precheck.rb). The CLI glue lives in bin/xcode-precheck.rb.
module XcodePrecheck
  # A `xcrun simctl list devices` row: "    <name> (<UUID>) (<state>)".
  # Anchoring on the UUID lets device names that themselves contain
  # parentheses (e.g. "iPhone SE (3rd generation)") parse correctly.
  DEVICE_LINE = /^\s*(.+?) \(\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\) \(/.freeze

  # Extract the simulator name from an xcodebuild `-destination` spec in a
  # Makefile (or any text). Returns nil when no destination is present.
  def self.destination_name(makefile_text)
    m = makefile_text.match(/-destination\s+"[^"]*?name=([^,"]+)/)
    m && m[1].strip
  end

  # All device names listed in `xcrun simctl list devices` output, in order.
  def self.device_names(simctl_text)
    simctl_text.each_line.filter_map do |line|
      m = line.match(DEVICE_LINE)
      m && m[1].strip
    end
  end

  # True when a device with exactly this name appears in the list (so
  # "iPhone 17" does not match "iPhone 17 Pro").
  def self.simulator_available?(name, simctl_text)
    device_names(simctl_text).include?(name)
  end

  # Unique, sorted iPhone device names — used to suggest alternatives.
  def self.iphone_suggestions(simctl_text)
    device_names(simctl_text).select { |n| n.start_with?('iPhone') }.uniq.sort
  end

  # Compare on-disk Swift files against target-attached files and a grandfathered
  # baseline. Returns:
  #   :all_orphans — every file on disk not attached to any target
  #   :new_orphans — orphans NOT in the baseline (these should fail the gate)
  #   :resolved    — baseline entries that are no longer orphans (baseline is stale)
  def self.orphan_report(disk, attached, baseline)
    all_orphans = disk - attached
    {
      all_orphans: all_orphans,
      new_orphans: all_orphans - baseline,
      resolved: baseline - all_orphans
    }
  end
end
