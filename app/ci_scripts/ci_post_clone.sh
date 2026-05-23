#!/usr/bin/env bash
# Apple Xcode Cloud の予約 hook: リポジトリ clone 直後に実行される。
# Secrets (Keys.plist / GoogleService-Info.plist) を base64 Env Var から復元し、
# CocoaPods 依存を取得する。
#
# 設計: docs/superpowers/specs/2026-05-23-xcode-cloud-migration-design.md
# 必要な Env Var: KEYS_PLIST_BASE64, GOOGLE_SERVICE_INFO_PLIST_BASE64
# (App Store Connect の Workflow Environment Variables に Secret 区分で登録)
set -euo pipefail

echo "==> ci_post_clone.sh: start"

APP_DIR="${CI_WORKSPACE}/app"

echo "==> Restoring Keys.plist"
echo "${KEYS_PLIST_BASE64}" | base64 -d > "${APP_DIR}/Keys.plist"

echo "==> Restoring GoogleService-Info.plist"
echo "${GOOGLE_SERVICE_INFO_PLIST_BASE64}" | base64 -d > "${APP_DIR}/GoogleService-Info.plist"

echo "==> Running pod install"
cd "${APP_DIR}"
pod install

echo "==> ci_post_clone.sh: done"
