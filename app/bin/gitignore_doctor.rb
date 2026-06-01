# frozen_string_literal: true

# Pure helpers for gitignore-doctor. Kept free of I/O so they can be unit-tested
# (see test_gitignore_doctor.rb). The CLI glue lives in bin/gitignore-doctor.rb.
#
# Oracle: `git check-ignore --no-index -v -- <path>` OUTPUT (not exit code).
# See docs/superpowers/specs/2026-06-01-gitignore-doctor-design.md and MEMORY
# feedback_gitignore_check_ignore_semantics.md for why exit code is unusable.
module GitignoreDoctor
  EXPECTATION_LINE = /\A(keep|ignore):\s*(.+)\z/.freeze

  # Parse the expectations fixture text into [{kind: :keep|:ignore, path: String}].
  # Skips blank lines and lines starting with '#'. Normalizes away a leading './';
  # a trailing '/' is preserved on purpose (see normalize_path) — it signals
  # directory intent.
  def self.parse_expectations(text)
    text.each_line.filter_map do |line|
      stripped = line.strip
      next if stripped.empty? || stripped.start_with?('#')

      m = stripped.match(EXPECTATION_LINE)
      next unless m

      { kind: m[1].to_sym, path: normalize_path(m[2].strip) }
    end
  end

  # Normalize a repo-relative path: drop a leading './'. A trailing '/' is KEPT
  # on purpose — it signals directory intent, which git check-ignore needs to
  # match a directory-only pattern (e.g. "Pods/") when the path is absent on disk
  # (fresh clone / before `make install`). Stripping it would cause an
  # environment-dependent false "NOT ignored". See the design doc's trap section.
  def self.normalize_path(path)
    path.sub(%r{\A\./}, '')
  end

  # Decide whether a path is ignored, from the OUTPUT of
  # `git check-ignore --no-index -v -- <path>`. The output is 0 or 1 line:
  #   "<source>:<line>:<pattern>\t<path>"
  # We never use the exit code (it returns 0 even for a '!' negation).
  #   - empty output            -> not ignored (no rule matched)
  #   - matched pattern is '!…'  -> not ignored (effective whitelist)
  #   - any other matched rule   -> ignored
  # Split on TAB first, then strip the leading "source:line:" so a pattern that
  # itself contains ':' is parsed correctly.
  def self.ignored?(check_ignore_output)
    line = check_ignore_output.to_s.strip
    return false if line.empty?

    meta = line.split("\t", 2).first        # "<source>:<line>:<pattern>"
    pattern = meta.sub(/\A[^:]*:\d+:/, '')   # strip "source:line:"
    !pattern.start_with?('!')
  end

  # Compare expectations against per-path `git check-ignore` outputs.
  # `results` maps a path String to the raw check-ignore output String.
  # Returns a list of violations: [{path:, kind:, message:}].
  #   keep   + ignored      -> violation (#31: a must-keep path is ignored)
  #   ignore + not ignored  -> violation (#9: a must-ignore path leaks through)
  def self.evaluate(expectations, results)
    expectations.filter_map do |exp|
      output = results.fetch(exp[:path], '')
      is_ignored = ignored?(output)

      case exp[:kind]
      when :keep
        next unless is_ignored

        { path: exp[:path], kind: :keep,
          message: "expected to be committable but is IGNORED by .gitignore" }
      when :ignore
        next if is_ignored

        { path: exp[:path], kind: :ignore,
          message: "expected to be ignored but is NOT ignored by .gitignore" }
      end
    end
  end
end
