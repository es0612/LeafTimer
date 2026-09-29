#!/usr/bin/env ruby
# frozen_string_literal: true

# claude-md-size-check: fail when the repo-root CLAUDE.md exceeds the byte limit.
#
# Issue #171.
#
# Usage:
#   ruby bin/claude-md-size-check.rb                # repo 直下の CLAUDE.md
#   ruby bin/claude-md-size-check.rb <path>         # 明示パス (fixture 用)
#
# Exit code 0 = 上限以内、1 = 上限超過 or ファイルが無い。

require_relative 'claude_md_size_check'

REPO_ROOT = File.expand_path('../..', __dir__) # app/bin -> app -> repo root

path = ARGV[0] || File.join(REPO_ROOT, 'CLAUDE.md')

unless File.file?(path)
  warn "❌ claude-md-size-check failed: #{path} が無い"
  exit 1
end

r = ClaudeMdSizeCheck.result(bytesize: File.size(path))
name = File.basename(path)

def commas(n)
  n.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
end

if r[:ok]
  puts "✅ claude-md-size-check passed (#{name} #{commas(r[:bytesize])} / #{commas(r[:limit])} bytes)"
  exit 0
end

warn "❌ claude-md-size-check failed: #{name} #{commas(r[:bytesize])} / #{commas(r[:limit])} bytes (+#{commas(r[:over])})"
warn '   直し方: 事故の経緯・PR 番号・実測値は docs/claude-lessons-archive.md へ移し、CLAUDE.md には「何をするか」だけ残す'
warn '   作業時だけ要る手順 (Simulator 検証・Xcode 構成など) は .claude/skills/ の skill へ移し、CLAUDE.md は 1 行のポインタにする'
exit 1
