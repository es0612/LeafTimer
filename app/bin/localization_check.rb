# frozen_string_literal: true

# Pure helpers for localization-check. Kept free of I/O so they can be
# unit-tested (see test_localization_check.rb). The CLI glue lives in
# bin/localization-check.rb.
module LocalizationCheck
  # NSLocalizedString("key", comment: ...) — the key may sit on a *following*
  # line (AboutSettingsSection.swift:36-39 does exactly that), so this pattern
  # deliberately spans newlines. A line-anchored grep silently misses those
  # calls and then reports a perfectly live key as "unused".
  CODE_KEY = /NSLocalizedString\(\s*"((?:[^"\\]|\\.)*)"/m.freeze

  # A key definition in a .strings file: "key" = "value";
  # Anchored at line start so that a `//` comment line (which never begins
  # with a quote) needs no special handling.
  STRINGS_KEY = /^\s*"((?:[^"\\]|\\.)*)"\s*=/.freeze

  BLOCK_COMMENT = %r{/\*.*?\*/}m.freeze

  # Every NSLocalizedString key literal, in source order, repeats included.
  def self.code_keys(swift_text)
    swift_text.scan(CODE_KEY).flatten
  end

  # Every key definition, in file order, repeats included — callers rely on
  # the repeats to detect duplicate definitions.
  def self.strings_keys(strings_text)
    strings_text.gsub(BLOCK_COMMENT, '')
                .each_line
                .filter_map { |line| line[STRINGS_KEY, 1] }
  end

  # Keys defined two or more times in one file. iOS keeps the last definition
  # and drops the earlier ones without a warning.
  def self.duplicate_keys(strings_text)
    strings_keys(strings_text).tally.select { |_key, count| count > 1 }.keys.sort
  end

  # Cross-check code keys against every locale's .strings text.
  #   locale_texts: { "ja" => <file text>, "en" => <file text> }
  def self.report(code_keys, locale_texts)
    used    = code_keys.uniq
    defined = locale_texts.transform_values { |text| strings_keys(text).uniq }
    union   = defined.values.flatten.uniq

    {
      missing: defined.transform_values { |keys| (used - keys).sort },
      parity: defined.transform_values { |keys| (union - keys).sort },
      duplicates: locale_texts.transform_values { |text| duplicate_keys(text) },
      unused: (union - used).sort
    }
  end
end
