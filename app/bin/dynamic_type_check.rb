# frozen_string_literal: true

# Pure helpers for dynamic-type-check. Kept free of I/O so they can be
# unit-tested (see test_dynamic_type_check.rb). The CLI glue lives in
# bin/dynamic-type-check.rb.
module DynamicTypeCheck
  # A hard-coded font size: `.system(size: <numeric literal>`.
  #
  # Two properties this pattern must have, both learned the hard way:
  #
  #   1. `\s*` between the tokens lets it span newlines. TimerView.swift wraps
  #      the call as `.font(.system(\n    size: 78, ...)`, and a line-anchored
  #      match silently misses it — 39 hits where there are really 40.
  #
  #   2. It requires a digit *immediately after* `size:`. The post-migration
  #      code reads `size: min(timerFontSize, 110)`, which contains the literal
  #      110; a looser "any digit inside .system(...)" pattern would flag the
  #      very code this check exists to allow, and the guard would fail its own
  #      pull request.
  #
  # `.font(` is deliberately not required, so `Font.system(size: 12)` is caught
  # too.
  #
  # Issue #108: two more shapes that also disable Dynamic Type —
  #   `Font.custom("Name", fixedSize: 15)`  and  `UIFont.systemFont(ofSize: 15)`
  #   (plus boldSystemFont / italicSystemFont / monospacedSystemFont …).
  # Same principle: the token right after `fixedSize:` / `ofSize:` must be a
  # digit. `Font.custom("Name", size: 15)` scales with the body text style
  # (per Apple's docs) and stays allowed, as does
  # `UIFont.preferredFont(forTextStyle:)`.
  FIXED_FONT_SIZE = %r{
    (?:
      \.system\(\s*size:                  # .system(size: 15)
      | \.custom\([^)]*?,\s*fixedSize:     # Font.custom("Name", fixedSize: 15) / .custom(…)
      | \.\w*[sS]ystemFont\(\s*ofSize:     # UIFont.systemFont(ofSize: 15), boldSystemFont, …
    )
    \s*[0-9]
  }mx.freeze

  # 1-indexed line numbers of every hard-coded font size, in source order.
  def self.violations(swift_text)
    swift_text.enum_for(:scan, FIXED_FONT_SIZE).map do
      swift_text[0...Regexp.last_match.begin(0)].count("\n") + 1
    end
  end
end
