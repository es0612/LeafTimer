#!/usr/bin/env ruby
# frozen_string_literal: true

# store-screenshots: capture + compose the App Store screenshots (Issue #161).
#
# 1. Debug ビルドを 1 回だけ作る (DEBUG 起動引数フックを使うため Release 不可)
# 2. 機種ごとの専用 Simulator (LeafTimer-Store-<device>) を UDID で扱う。
#    同名機種が複数ある環境や他セッションの Booted 機と混ざらない (CLAUDE.md ルール 30)
# 3. locale x screen ごとに起動引数を変えて起動 → 生スクショ (raw/)
# 4. bin/store-screenshot-compose.swift で背景 + コピーを合成 (final/)
#
# Usage: ruby bin/store-screenshots.rb   (make store-screenshots から呼ぶ)
# 出力: build/store-screenshots/{raw,final}/<locale>/<device>/<screen id>.png

require 'fileutils'
require 'json'
require 'open3'

APP_ROOT = File.expand_path('..', __dir__)
BUNDLE_ID = 'jp.ema.LeafTimer'
OUT_DIR = File.join(APP_ROOT, 'build', 'store-screenshots')
DERIVED_DATA = File.join(OUT_DIR, 'DerivedData')
COMPOSE_BIN = File.join(OUT_DIR, 'compose')
# 起動 → 描画 → 実行中画面のカウントダウンが 1 秒以上進むまでの待ち時間 (実測で決定)。
LAUNCH_WAIT_SECONDS = 6

def run!(*cmd)
  out, status = Open3.capture2e(*cmd)
  abort "❌ failed: #{cmd.join(' ')}\n#{out}" unless status.success?
  out
end

def latest_ios_runtime
  runtimes = JSON.parse(run!('xcrun', 'simctl', 'list', 'runtimes', 'available', '-j'))['runtimes']
  ios = runtimes.select { |r| r['identifier'].include?('SimRuntime.iOS-') }
  abort '❌ no available iOS runtime' if ios.empty?
  ios.max_by { |r| Gem::Version.new(r['version']) }['identifier']
end

def simulator_udid(name, device_type, runtime)
  devices = JSON.parse(run!('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))['devices']
  existing = devices.fetch(runtime, []).find { |d| d['name'] == name }
  return existing['udid'] if existing

  run!('xcrun', 'simctl', 'create', name, device_type, runtime).strip
end

config = JSON.parse(File.read(File.join(APP_ROOT, 'store-screenshots', 'screens.json')))

FileUtils.rm_rf([File.join(OUT_DIR, 'raw'), File.join(OUT_DIR, 'final')])

puts '▶ building Debug app...'
build_log = run!(
  'xcodebuild', '-workspace', File.join(APP_ROOT, 'LeafTimer.xcworkspace'), '-scheme', 'LeafTimer',
  '-configuration', 'Debug', '-destination', 'generic/platform=iOS Simulator',
  '-derivedDataPath', DERIVED_DATA, 'build'
)
abort "❌ build failed\n#{build_log[-2000..]}" unless build_log.include?('** BUILD SUCCEEDED **')
app_path = File.join(DERIVED_DATA, 'Build', 'Products', 'Debug-iphonesimulator', 'LeafTimer.app')

puts '▶ compiling compose tool...'
run!('swiftc', '-O', File.join(APP_ROOT, 'bin', 'store-screenshot-compose.swift'), '-o', COMPOSE_BIN)

runtime = latest_ios_runtime
config.fetch('devices').each do |device, spec|
  udid = simulator_udid("LeafTimer-Store-#{device}", spec.fetch('device_type'), runtime)
  puts "▶ #{device} (#{udid})"
  system('xcrun', 'simctl', 'boot', udid, err: File::NULL) # 既に Booted なら失敗するが無視してよい
  run!('xcrun', 'simctl', 'bootstatus', udid, '-b')
  system('xcrun', 'simctl', 'uninstall', udid, BUNDLE_ID, err: File::NULL) # 前回の UserDefaults を消す
  run!('xcrun', 'simctl', 'install', udid, app_path)
  run!('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41', '--batteryState', 'charged',
       '--batteryLevel', '100', '--cellularBars', '4', '--wifiBars', '3')
  # ATT と通知許可のシステムダイアログがスクショに被らないよう事前付与 (CLAUDE.md ルール 32)
  run!('applesimutils', '--byId', udid, '--bundle', BUNDLE_ID,
       '--setPermissions', 'userTracking=YES, notifications=YES')

  config.fetch('locales').each do |locale|
    config.fetch('screens').each do |screen|
      relative = File.join(locale, device, "#{screen.fetch('id')}.png")
      raw = File.join(OUT_DIR, 'raw', relative)
      final = File.join(OUT_DIR, 'final', relative)
      FileUtils.mkdir_p([File.dirname(raw), File.dirname(final)])

      system('xcrun', 'simctl', 'terminate', udid, BUNDLE_ID, err: File::NULL)
      run!('xcrun', 'simctl', 'launch', udid, BUNDLE_ID, *screen.fetch('args'),
           '-AppleLanguages', "(#{locale})", '-AppleLocale', locale)
      sleep LAUNCH_WAIT_SECONDS
      run!('xcrun', 'simctl', 'io', udid, 'screenshot', raw)

      width, height = spec.fetch('size')
      run!(COMPOSE_BIN, raw, final, width.to_s, height.to_s, locale, *screen.fetch('copy').fetch(locale))
      puts "  ✓ #{relative}"
    end
  end
  system('xcrun', 'simctl', 'terminate', udid, BUNDLE_ID, err: File::NULL)
  run!('xcrun', 'simctl', 'shutdown', udid)
end

puts "✅ store-screenshots: composed into #{File.join(OUT_DIR, 'final')}"
