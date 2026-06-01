# frozen_string_literal: true

# Pure helpers for gitignore-doctor. Kept free of I/O so they can be unit-tested
# (see test_gitignore_doctor.rb). The CLI glue lives in bin/gitignore-doctor.rb.
#
# Oracle: `git check-ignore --no-index -v -- <path>` OUTPUT (not exit code).
# See docs/superpowers/specs/2026-06-01-gitignore-doctor-design.md and MEMORY
# feedback-gitignore-check-ignore-semantics for why exit code is unusable.
module GitignoreDoctor
  EXPECTATION_LINE = /\A(keep|ignore):\s*(.+)\z/.freeze

  # Parse the expectations fixture text into [{kind: :keep|:ignore, path: String}].
  # Skips blank lines and lines starting with '#'. Normalizes a leading './' and a
  # trailing '/' so the same path written either way compares equal.
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
end
