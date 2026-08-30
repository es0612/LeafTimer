#!/usr/bin/env bash
# Issue #141: CI の CocoaPods を Podfile.lock の COCOAPODS 行と同じバージョンに揃える。
# バージョン差があると pod install の pbxproj 再シリアライズが変わり、
# pr-tests.yml 末尾の sort gate (git diff --exit-code project.pbxproj) が偽 fail する。
#
# CI 実測 (PR #144, run 33297533411) で判明した挙動: managed runner の `pod` は
# brew ruby (3.4) の RubyGems binstub で、**binstub は常にそのgem環境内で最も新しい
# インストール済みバージョンを activate する**。`gem install cocoapods -v $want` で
# 目的バージョンを追加インストールしても、より新しいバージョンが既に入っていれば
# `pod --version` はそのまま新しい方を返し続け、単純な再検証は必ず不一致になる。
# そのため確認は `pod --version` ではなく RubyGems のバージョンセレクタ
# `pod _<ver>_ --version` (Podfile.lock 通りのそのバージョンを明示的に選んで実行) で
# 行う。workflow の Pod install ステップも `pod _<ver>_ install` を使う。
#
# Usage:
#   bash bin/ensure-cocoapods-version.sh              # 不一致なら gem install で揃える
#   bash bin/ensure-cocoapods-version.sh --check-only # 不一致なら exit 1 (インストールしない)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="${SCRIPT_DIR}/../Podfile.lock"
CHECK_ONLY=false
case "${1:-}" in
  --check-only) CHECK_ONLY=true ;;
  "") ;;
  *) echo "usage: $0 [--check-only]" >&2; exit 2 ;;
esac

want="$(sed -n 's/^COCOAPODS: *//p' "$LOCK" | tr -d '[:space:]')"
if [ -z "$want" ]; then
  echo "❌ ensure-cocoapods-version: COCOAPODS 行が $LOCK に無い" >&2
  exit 2
fi

have="$(pod --version 2>/dev/null | tr -d '[:space:]' || true)"
if [ "$have" = "$want" ]; then
  echo "✅ cocoapods $have matches Podfile.lock"
  exit 0
fi

echo "⚠️  cocoapods mismatch: have='${have:-none}' want='$want' (Podfile.lock)"
if $CHECK_ONLY; then
  exit 1
fi

if ! gem install cocoapods -v "$want" --no-document; then
  echo "⚠️  gem install (no sudo) 失敗。sudo で再試行します" >&2
  sudo gem install cocoapods -v "$want" --no-document
fi
hash -r

# binstub は常に最新版を activate するため `pod --version` では確認できない。
# RubyGems のバージョンセレクタで、Podfile.lock が指定するそのバージョンが
# インストール済みで実行できることを直接確認する。
have="$(pod "_${want}_" --version 2>/dev/null | tr -d '[:space:]' || true)"
if [ "$have" != "$want" ]; then
  echo "❌ ensure-cocoapods-version: install 後も pod _${want}_ が解決できない (got '${have:-none}')" >&2
  echo "   command -v pod: $(command -v pod || echo 'not found')" >&2
  echo "   gem list cocoapods:" >&2
  gem list cocoapods 2>/dev/null >&2 || true
  echo "   gem env gemdir: $(gem env gemdir 2>/dev/null || echo 'unknown')" >&2
  echo "   PATH=$PATH" >&2
  exit 1
fi
echo "✅ cocoapods $want available via version selector (pod _${want}_)"
