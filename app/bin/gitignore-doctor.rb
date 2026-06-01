#!/usr/bin/env ruby
# frozen_string_literal: true

# gitignore-doctor: verify that .gitignore behaves as intended.
#
# Reads bin/gitignore-doctor-expectations.txt (keep:/ignore: lines), then for
# each path runs `git check-ignore --no-index -v -- <path>` AT THE REPO ROOT and
# decides ignored/not via the matched rule (never the exit code). Reports any
# mismatch and exits non-zero. See the design doc + MEMORY for the rationale.
#
# Usage:
#   ruby bin/gitignore-doctor.rb     # run checks, non-zero exit on violation
#
# Exit code 0 = all expectations met (or fixture absent/empty); 1 = violation
# or a git failure.

require 'open3'
require_relative 'gitignore_doctor'

SCRIPT_DIR    = __dir__                                   # app/bin
FIXTURE_FILE  = File.join(SCRIPT_DIR, 'gitignore-doctor-expectations.txt')

# Resolve the repository top level so check-ignore path args are root-relative.
def repo_root
  root, status = Open3.capture2('git', 'rev-parse', '--show-toplevel')
  raise 'not inside a git repository' unless status.success?

  root.strip
end

# Run `git check-ignore --no-index -v -- <path>` at the repo root, return its
# stdout (0 or 1 line). check-ignore exits 1 when nothing matches; that is a
# normal "not ignored" result, NOT an error, so we don't treat exit on it.
def check_ignore_output(root, path)
  out, _err, _status = Open3.capture3(
    'git', '-C', root, 'check-ignore', '--no-index', '-v', '--', path
  )
  out
end

# --- run --------------------------------------------------------------------

unless File.exist?(FIXTURE_FILE)
  puts "⚠️  gitignore-doctor: no expectations file (#{File.basename(FIXTURE_FILE)}); skipped"
  exit 0
end

expectations = GitignoreDoctor.parse_expectations(File.read(FIXTURE_FILE))

if expectations.empty?
  puts '✅ gitignore-doctor: no expectations declared (nothing to check)'
  exit 0
end

begin
  root = repo_root
rescue RuntimeError => e
  warn "❌ gitignore-doctor: #{e.message}"
  exit 1
end

results = expectations.each_with_object({}) do |exp, acc|
  acc[exp[:path]] = check_ignore_output(root, exp[:path])
end

violations = GitignoreDoctor.evaluate(expectations, results)

if violations.empty?
  puts "✅ gitignore-doctor: #{expectations.size} expectation(s) satisfied"
  exit 0
else
  warn "❌ gitignore-doctor: #{violations.size} violation(s):"
  violations.each do |v|
    warn "   - [#{v[:kind]}] #{v[:path]}: #{v[:message]}"
  end
  warn '   → fix the .gitignore rule or update bin/gitignore-doctor-expectations.txt'
  exit 1
end
