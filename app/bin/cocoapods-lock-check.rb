#!/usr/bin/env ruby
# frozen_string_literal: true

# cocoapods-lock-check: verify that the cocoapods version pinned by
# app/Gemfile.lock equals the `COCOAPODS:` trailer in app/Podfile.lock.
#
# Issue #143. Replaces bin/ensure-cocoapods-version.sh (#141), which tried to
# install the right cocoapods into the runner's RubyGems and could not
# downgrade past the binstub. With Bundler the version is whatever
# Gemfile.lock says, so the only thing left to guard is drift between the two
# lock files.
#
# Usage:
#   ruby bin/cocoapods-lock-check.rb                              # app/Gemfile.lock vs app/Podfile.lock
#   ruby bin/cocoapods-lock-check.rb <Gemfile.lock> <Podfile.lock> # explicit paths (fixtures)
#
# Exit code 0 = versions match; 1 = mismatch or a lock file is unreadable.

require_relative 'cocoapods_lock_check'

PROJECT_DIR = File.expand_path('..', __dir__) # app/

gemfile_lock = ARGV[0] || File.join(PROJECT_DIR, 'Gemfile.lock')
podfile_lock = ARGV[1] || File.join(PROJECT_DIR, 'Podfile.lock')

[gemfile_lock, podfile_lock].each do |path|
  next if File.file?(path)

  warn "❌ cocoapods-lock-check failed: #{path} が無い"
  exit 1
end

report = CocoapodsLockCheck.report(File.read(gemfile_lock), File.read(podfile_lock))

if report[:ok]
  puts "✅ cocoapods-lock-check passed (#{report[:gem]})"
  exit 0
else
  warn "❌ cocoapods-lock-check failed: #{report[:reason]}"
  warn "   Gemfile.lock: #{gemfile_lock}"
  warn "   Podfile.lock: #{podfile_lock}"
  warn '   直し方: Gemfile の cocoapods pin を Podfile.lock の COCOAPODS: 行に合わせて `bundle install`、' \
       'または `bundle exec pod install` で Podfile.lock を書き直す'
  exit 1
end
