#!/usr/bin/env bash
# Issue #141: CI の CocoaPods を Podfile.lock の COCOAPODS 行と同じバージョンに揃える。
# バージョン差があると pod install の pbxproj 再シリアライズが変わり、
# pr-tests.yml 末尾の sort gate (git diff --exit-code project.pbxproj) が偽 fail する。
#
# Usage:
#   bash bin/ensure-cocoapods-version.sh              # 不一致なら gem install で揃える
#   bash bin/ensure-cocoapods-version.sh --check-only # 不一致なら exit 1 (インストールしない)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="${SCRIPT_DIR}/../Podfile.lock"
CHECK_ONLY=false
[ "${1:-}" = "--check-only" ] && CHECK_ONLY=true

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

sudo gem install cocoapods -v "$want" --no-document
hash -r
have="$(pod --version | tr -d '[:space:]')"
if [ "$have" != "$want" ]; then
  echo "❌ ensure-cocoapods-version: install 後も不一致 have='$have' want='$want'" >&2
  exit 1
fi
echo "✅ cocoapods $have installed to match Podfile.lock"
