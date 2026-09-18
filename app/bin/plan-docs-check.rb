#!/usr/bin/env ruby
# frozen_string_literal: true

# plan-docs-check: verify the naming convention of docs/superpowers/{plans,specs}.
#
# Issue #84. Directory root = work in flight → strict name
# (YYYY-MM-DD-issue-NN[-NN...]-slug.md). archive/ = merged history → date prefix
# only. The move into archive/ is the plan's own final task (CLAUDE.md ルール 44),
# so on master both roots are normally empty.
#
# Usage:
#   ruby bin/plan-docs-check.rb                      # repo の docs/superpowers
#   ruby bin/plan-docs-check.rb <superpowers dir>    # 明示パス (fixture 用)
#
# Exit code 0 = すべて規則どおり、1 = 違反あり or ディレクトリが無い。

require 'date'
require_relative 'plan_docs_check'

REPO_ROOT = File.expand_path('../..', __dir__) # app/bin -> app -> repo root

def md_names(dir)
  return [] unless File.directory?(dir)

  # 拡張子の比較は大文字小文字を無視する: `.MD` を黙って対象外にすると
  # 命名 checker として本末転倒 (ROOT_NAME/ARCHIVE_NAME 側は小文字 `.md` を
  # 要求したままなので、大文字拡張子はここを通過したうえで違反として拾われる)。
  Dir.children(dir).select { |n| n.downcase.end_with?('.md') && File.file?(File.join(dir, n)) }
end

base = ARGV[0] || File.join(REPO_ROOT, 'docs', 'superpowers')

unless File.directory?(base)
  warn "❌ plan-docs-check failed: #{base} が無い"
  exit 1
end

# 実行日は 1 回だけ取って全 kind で共有する (日付をまたいだ実行でも判定がぶれない)。
today = Date.today

counts = {}
violations = []

%w[plans specs].each do |kind|
  root_dir = File.join(base, kind)
  # plans/ specs/ 自体が無いと md_names は [] を返すだけなので、何も検出せず
  # exit 0 になる vacuous green を hard fail で塞ぐ (dynamic-type-check.rb の
  # SOURCE_DIR ガードと同型)。archive/ は新規チェックアウトに無くて正常なので
  # 対象外。
  unless File.directory?(root_dir)
    warn "❌ plan-docs-check failed: #{root_dir} が無い"
    exit 1
  end

  root_names = md_names(root_dir)
  archive_names = md_names(File.join(root_dir, 'archive'))
  counts[kind] = { root: root_names.size, archive: archive_names.size }
  PlanDocsCheck.violations(root_names: root_names, archive_names: archive_names).each do |v|
    violations << v.merge(kind: kind)
  end
  PlanDocsCheck.stale(root_names: root_names, today: today).each do |v|
    violations << v.merge(kind: kind)
  end
end

if violations.empty?
  puts format('✅ plan-docs-check passed (root: plans %d / specs %d, archive: plans %d / specs %d)',
              counts['plans'][:root], counts['specs'][:root],
              counts['plans'][:archive], counts['specs'][:archive])
  exit 0
end

warn "❌ plan-docs-check failed: #{violations.size} 件"
violations.each do |v|
  sub = v[:scope] == :archive ? '/archive' : ''
  warn "   docs/superpowers/#{v[:kind]}#{sub}/#{v[:name]}: #{v[:reason]}"
end
warn '   直し方: 稼働中は YYYY-MM-DD-issue-NN[-NN…]-slug.md。merge 前に archive/ へ git mv する (CLAUDE.md ルール 44)'
warn '   issue 未起票なら先に gh issue create — 厳格名は保存前に issue 番号を要求する (CLAUDE.md ルール 44)'
exit 1
