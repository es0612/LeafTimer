# frozen_string_literal: true

# Pure helpers for claude-md-size-check (Issue #171). Kept free of I/O so they
# can be unit-tested (see test_claude_md_size_check.rb). The CLI glue lives in
# bin/claude-md-size-check.rb.
#
# Why this exists: CLAUDE.md was compressed to 11.5KB in #111 (2026-08-15) and
# grew back to 30KB in six weeks, because "add one line to CLAUDE.md" was the
# only place a lesson could go. The limit forces the opposite move: when it is
# exceeded, incident history goes to docs/claude-lessons-archive.md and
# task-specific procedures go to .claude/skills/.
module ClaudeMdSizeCheck
  # UTF-8 bytes, not characters: Japanese is 3 bytes per character, and the
  # issue and PR bodies talk about the size in KB.
  LIMIT_BYTES = 18_000

  # Returns { ok: Boolean, bytesize: Integer, limit: Integer, over: Integer }.
  # Exactly LIMIT_BYTES is ok; over is 0 when ok.
  def self.result(bytesize:, limit: LIMIT_BYTES)
    over = bytesize - limit
    { ok: over <= 0, bytesize: bytesize, limit: limit, over: [over, 0].max }
  end
end
