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

require_relative 'plan_docs_check'

REPO_ROOT = File.expand_path('../..', __dir__) # app/bin -> app -> repo root

def md_names(dir)
  return [] unless File.directory?(dir)

  Dir.children(dir).select { |n| n.end_with?('.md') && File.file?(File.join(dir, n)) }
end

base = ARGV[0] || File.join(REPO_ROOT, 'docs', 'superpowers')

unless File.directory?(base)
  warn "❌ plan-docs-check failed: #{base} が無い"
  exit 1
end

counts = {}
violations = []

%w[plans specs].each do |kind|
  root_dir = File.join(base, kind)
  root_names = md_names(root_dir)
  archive_names = md_names(File.join(root_dir, 'archive'))
  counts[kind] = { root: root_names.size, archive: archive_names.size }
  PlanDocsCheck.violations(root_names: root_names, archive_names: archive_names).each do |v|
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
exit 1
