#!/usr/bin/env bash
# Apple Xcode Cloud の予約 hook: リポジトリ clone 直後に実行される。
# Secrets (Keys.plist / GoogleService-Info.plist) を base64 Env Var から復元し、
# CocoaPods 依存を取得する。
#
# 設計: docs/superpowers/specs/archive/2026-05-23-xcode-cloud-migration-design.md
# 必要な Env Var: KEYS_PLIST_BASE64, GOOGLE_SERVICE_INFO_PLIST_BASE64
# (App Store Connect の Workflow Environment Variables に Secret 区分で登録)
set -euo pipefail

echo "==> ci_post_clone.sh: start"

# Xcode Cloud は CI_WORKSPACE を提供しない (実環境で unbound variable で失敗)。
# スクリプト自身の位置から app/ を解決し env var 依存を排除する。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Restoring Keys.plist"
echo "${KEYS_PLIST_BASE64}" | base64 -d > "${APP_DIR}/Keys.plist"

echo "==> Restoring GoogleService-Info.plist"
echo "${GOOGLE_SERVICE_INFO_PLIST_BASE64}" | base64 -d > "${APP_DIR}/GoogleService-Info.plist"

# Issue #147: CocoaPods は pr-tests.yml と同じく app/Gemfile.lock で固定し bundle exec で動かす。
# Xcode Cloud には brew の cocoapods 1.17.0 が preinstall 済みで、素の pod は Podfile.lock の 1.16.2
# とずれていた (build 45 のログ: "cocoapods 1.17.0 is already installed")。
# macOS の system ruby は lock の activesupport 7.2 (Ruby >= 3.1) を解決できないので、
# app/.ruby-version (3.4.x) と同じ minor の brew ruby@3.4 (keg-only) を PATH 先頭に置く。
echo "==> Installing Ruby 3.4 (app/.ruby-version と同じ minor)"
brew install ruby@3.4
RUBY_PREFIX="$(brew --prefix ruby@3.4)"
export PATH="${RUBY_PREFIX}/bin:${PATH}"
which ruby
ruby --version
bundle --version

echo "==> Installing CocoaPods via Bundler (Gemfile.lock 固定)"
cd "${APP_DIR}"
bundle install
# $(...) を echo に埋め込むと set -e でも失敗が素通りするので、先に変数へ入れる。
POD_VERSION="$(bundle exec pod --version)"
echo "cocoapods via bundler: ${POD_VERSION}"

echo "==> Running pod install"
bundle exec pod install

echo "==> ci_post_clone.sh: done"
