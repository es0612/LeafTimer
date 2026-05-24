# Issue #26 + #27: ダークモード視認性改善 + ビルド情報表示削除 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settings 画面の Version/Build 表示を削除 (Issue #27) し、TimerView のツールバーアイコン視認性とテキスト色をダークモードでも読めるよう修正 (Issue #26) する。

**Architecture:** UI 表層のみの変更。アイコンは asset catalog の `template-rendering-intent` 指定を追加して既存の `.foregroundColor(.primary)` を有効化。テキスト色は hardcoded RGB を SwiftUI built-in `.primary`/`.secondary` に置換。ビルド情報は VStack ブロックごと削除。

**Tech Stack:** SwiftUI / Xcode 15+ / iOS 17+ / xcodebuild + iPhone 17 Simulator

**Branch:** `feature/issue-26-27-dark-mode-improvements` (master から +3 commit: CLAUDE.md 振り返り、spec 初版、spec scope 縮小)

**Spec:** `docs/superpowers/specs/2026-05-24-dark-mode-and-hide-build-info-design.md`

---

### Task 1: Issue #27 — ResetSettingsSection から Version/Build 表示削除

**Files:**
- Modify: `app/LeafTimer/View/Settings/ResetSettingsSection.swift:41-63`

**何を消すか**: lines 41-63 の `// App Information` コメント + `VStack(alignment: .leading, spacing: 12)` ブロック (4 つの `Text` を含む) + 直後の `.padding(.vertical, 4)`。

- [ ] **Step 1: 削除対象の line 範囲を最終確認 (上書き事故防止)**

```bash
sed -n '41,63p' /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/View/Settings/ResetSettingsSection.swift
```

Expected output (抜粋):
```
            // App Information
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Version")
...
            }
            .padding(.vertical, 4)
```

もし 41 行目が `// App Information` でなければ、ファイルが変わっている。STOP し人間に確認。

- [ ] **Step 2: 該当ブロックを Edit ツールで削除**

`old_string`:
```swift

            // App Information
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Version")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }

                HStack {
                    Text("Build")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 4)

```

`new_string`: 空文字列 (削除のみ — 直前の `.confirmationDialog ... } message: { Text(...) }` の後に空行 1 つを残す形になる)

- [ ] **Step 3: 削除後の整合性チェック**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && grep -n 'CFBundleVersion\|CFBundleShortVersionString\|App Information' app/LeafTimer/View/Settings/ResetSettingsSection.swift
```

Expected: 出力なし (全て消えた)

- [ ] **Step 4: unit-tests を走らせて regression が無いことを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && set -o pipefail; make unit-tests 2>&1 | tail -30
```

Bash tool 呼び出し時に `timeout: 600000` (10 分) を必ず指定する。Expected: 最後に `** TEST SUCCEEDED **` (xcodebuild) が表示される。失敗時は `PIPESTATUS[0]` 確認。

- [ ] **Step 5: Issue #27 として commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/View/Settings/ResetSettingsSection.swift
git commit -m "$(cat <<'EOF'
Issue #27: Settings 画面からバージョン/ビルド表示を削除

ユーザー向け情報として不要な CFBundleShortVersionString / CFBundleVersion
の表示 (System セクション内 VStack) を削除。リセットボタンは残す。

Closes #27

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Issue #26-A — reloadIcon の template-rendering 化

**Files:**
- Modify: `app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset/Contents.json`

- [ ] **Step 1: 現状を再確認**

```bash
cat /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset/Contents.json
```

Expected:
```json
{
  "images" : [
    {
      "filename" : "reloadIcon.pdf",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 2: properties block を追加**

Write tool で以下の内容に置換:

```json
{
  "images" : [
    {
      "filename" : "reloadIcon.pdf",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
```

注意: Xcode の JSON フォーマット (`" : "` — colon の前後に空白) を厳守。Python json.dump を使わないこと (xcstrings-bulk-update skill 参照、同じ罠が xcassets にもある)。Write tool で直書きすれば安全。

- [ ] **Step 3: 検証 — JSON valid + key 追加確認**

```bash
python3 -m json.tool /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset/Contents.json > /dev/null && echo "JSON valid"
grep -c 'template-rendering-intent' /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset/Contents.json
```

Expected: `JSON valid` + `1`

---

### Task 3: Issue #26-A — settingIcon の template-rendering 化

**Files:**
- Modify: `app/LeafTimer/App/Assets.xcassets/settingIcon.imageset/Contents.json`

- [ ] **Step 1: 現状確認**

```bash
cat /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/App/Assets.xcassets/settingIcon.imageset/Contents.json
```

Expected: filename を除いて Task 2 と同形。

- [ ] **Step 2: Write tool で properties block を追加**

```json
{
  "images" : [
    {
      "filename" : "settingIcon.pdf",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
```

- [ ] **Step 3: 検証**

```bash
python3 -m json.tool /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/App/Assets.xcassets/settingIcon.imageset/Contents.json > /dev/null && echo "JSON valid"
grep -c 'template-rendering-intent' /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/App/Assets.xcassets/settingIcon.imageset/Contents.json
```

Expected: `JSON valid` + `1`

---

### Task 4: Issue #26-B — TimerView の hardcoded gray 置換

**Files:**
- Modify: `app/LeafTimer/View/TimerView.swift:55`
- Modify: `app/LeafTimer/View/TimerView.swift:66`

- [ ] **Step 1: 削除対象行を確認**

```bash
sed -n '54,67p' /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/View/TimerView.swift
```

Expected:
```
                        )
                        .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65, opacity: 0.9))
                        .shadow(color: .gray, radius: 1, x: 1, y: 2)
                        .padding(.bottom, 50)
...
                    Text(NSLocalizedString("timer.todays_count", comment: "Today's pomodoro count label") + String(timerViewModel.todaysCount))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.9))
```

行ズレがあれば STOP。

- [ ] **Step 2: Edit tool で line 55 置換**

`old_string`:
```swift
                        .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65, opacity: 0.9))
```

`new_string`:
```swift
                        .foregroundColor(.primary.opacity(0.9))
```

- [ ] **Step 3: Edit tool で line 66 置換**

`old_string`:
```swift
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.9))
```

`new_string`:
```swift
                        .foregroundColor(.secondary.opacity(0.9))
```

- [ ] **Step 4: 置換確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && grep -n 'Color(red: 0\.' app/LeafTimer/View/TimerView.swift
```

Expected: 出力なし (line 55, 66 の Color(red:...) は消えた)

```bash
grep -n '\.primary\.opacity(0\.9)\|\.secondary\.opacity(0\.9)' /Users/shinya/workspace/claude/LeafTimer/app/LeafTimer/View/TimerView.swift
```

Expected: 2 行 (line 55, 66)

---

### Task 5: 全変更後の unit-tests 実行 (Issue #26 一括検証)

- [ ] **Step 1: lint + tests**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && set -o pipefail; make tests 2>&1 | tail -60
```

Bash tool で `timeout: 600000` 指定必須。Expected: SwiftLint warnings あっても OK だが error はゼロ、`** TEST SUCCEEDED **` で終了。

失敗時の typical cause:
- SwiftLint が `.primary.opacity(0.9)` を unused なんとかと誤認 → strict mode でなければ無視可
- xcodebuild の simulator boot 失敗 → 既存問題、Plan 範囲外

---

### Task 6: Issue #26 の変更を commit

- [ ] **Step 1: 対象ファイル一覧確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git status -s
```

Expected:
```
 M app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset/Contents.json
 M app/LeafTimer/App/Assets.xcassets/settingIcon.imageset/Contents.json
 M app/LeafTimer/View/TimerView.swift
?? docs/superpowers/plans/2026-05-24-issue-26-27-dark-mode-improvements.md
```

(plan ファイルは別 commit で扱う — Task 8 で commit する)

- [ ] **Step 2: Issue #26 として commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add \
  app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset/Contents.json \
  app/LeafTimer/App/Assets.xcassets/settingIcon.imageset/Contents.json \
  app/LeafTimer/View/TimerView.swift
git commit -m "$(cat <<'EOF'
Issue #26: ダークモード視認性改善 (アイコン + タイマー画面テキスト色)

- reloadIcon / settingIcon の Contents.json に template-rendering-intent: template を追加。
  既存の .foregroundColor(.primary) が初めて有効化され、light/dark で自動切替される。
- TimerView の timer 文字 / 本日カウント表示の hardcoded gray を
  .primary.opacity(0.9) / .secondary.opacity(0.9) に置換。ダークモードで読みやすくなる。

Closes #26

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Screenshot 検証 (light + dark mode)

REQUIRED SUB-SKILL: `ios-simulator-app-verification`

**Files:**
- Output: `/tmp/leaftimer-issue-26-27-light-timer.png`
- Output: `/tmp/leaftimer-issue-26-27-dark-timer.png`
- Output: `/tmp/leaftimer-issue-26-27-light-settings.png`
- Output: `/tmp/leaftimer-issue-26-27-dark-settings.png`

- [ ] **Step 1: シミュレータ準備**

```bash
xcrun simctl list devices available | grep 'iPhone 17' | head -3
```

Expected: 少なくとも 1 つの "iPhone 17" デバイスがあること。無ければ `xcrun simctl list devicetypes | grep 'iPhone-17'` で create 必要。

- [ ] **Step 2: シミュレータ起動 + アプリ build/install**

```bash
xcrun simctl boot 'iPhone 17' 2>&1 | tail -3 || true
open -a Simulator
sleep 5
cd /Users/shinya/workspace/claude/LeafTimer/app && set -o pipefail; xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -derivedDataPath /tmp/leaftimer-build build 2>&1 | tail -20
```

Bash timeout: 600000. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: install + launch (light mode)**

```bash
APP_PATH=$(find /tmp/leaftimer-build -name 'LeafTimer.app' -type d | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl ui booted appearance light
xcrun simctl launch booted jp.ema.LeafTimer 2>&1 | tail -3
sleep 3
xcrun simctl io booted screenshot /tmp/leaftimer-issue-26-27-light-timer.png
```

(bundle id `jp.ema.LeafTimer` は `app/LeafTimer.xcodeproj/project.pbxproj` の `PRODUCT_BUNDLE_IDENTIFIER` で確定済。マッチしなければ pbxproj から再確認)

- [ ] **Step 4: Settings 画面まで遷移して screenshot**

UserDefaults 経由で settings 画面状態を強制するか、手動でタップ確認するか。SwiftUI なので simctl tap は使えない (CLAUDE.md 振り返り)。代替: SettingView を直接 root にする一時 SwiftUI preview を立てるか、UserDefaults でフラグ制御。

実用的な妥協案: Settings 画面用の screenshot は手動でテスターに頼む。Plan 中で `[manual]` とマーク。

```bash
# manual: Open Simulator, tap top-right gear icon, take screenshot
# Save as /tmp/leaftimer-issue-26-27-light-settings.png
```

- [ ] **Step 5: dark mode に切替えて同じ手順**

```bash
xcrun simctl ui booted appearance dark
sleep 2
xcrun simctl terminate booted jp.ema.LeafTimer
xcrun simctl launch booted jp.ema.LeafTimer
sleep 3
xcrun simctl io booted screenshot /tmp/leaftimer-issue-26-27-dark-timer.png
# Manual: dark Settings screenshot too → /tmp/leaftimer-issue-26-27-dark-settings.png
```

- [ ] **Step 6: 視覚 review**

4 枚を user に提示し、以下を確認:
1. Light/dark で reloadIcon / settingIcon が両方とも見える (light は黒、dark は白に自動着色)
2. Timer 文字色が dark mode で読める (元: 薄灰色 → 後: primary 色)
3. Settings 画面に Version/Build 表示が無くなっている
4. 違和感 (色のコントラスト不足 etc.) があれば指摘してもらう

---

### Task 8: branch push + PR 作成

(Plan ファイルは既に commit 0cd5088 として branch に含まれる)

- [ ] **Step 1: 既存 PR の有無を確認 (CLAUDE.md 振り返り)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch origin && gh pr list --state all --head feature/issue-26-27-dark-mode-improvements
```

Expected: 出力なし (まだ PR 無し)

- [ ] **Step 2: branch push**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git push -u origin feature/issue-26-27-dark-mode-improvements 2>&1 | tail -5
```

- [ ] **Step 3: PR 作成**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr create \
  --title 'Issue #26 #27: ダークモード視認性改善 + ビルド情報表示削除' \
  --body "$(cat <<'EOF'
## Summary

- **Issue #27**: Settings 画面から不要な Version / Build 表示を削除
- **Issue #26**: TimerView ツールバーアイコン (reloadIcon / settingIcon) の dark mode 視認性を修正、タイマー文字色をシステム標準 `.primary` / `.secondary` に置換

## 設計判断

スコープ B 案 (アイコン + 主要画面の明らかな記述バグ) を採用。設計詳細は `docs/superpowers/specs/2026-05-24-dark-mode-and-hide-build-info-design.md` を参照。

plan 作成段階で `SessionStatsView` / `TimerControlsView` が dead code (commit 6096505 で書かれたが wire-up されていない) と判明したため、それらの色修正は本 PR の scope 外とし、別 issue 候補とする。

## Verification

Light / Dark 両方で TimerView と Settings 画面の screenshot を取得済 (PR コメント参照)。

## Test plan

- [x] `cd app && make unit-tests` で既存テスト pass を確認
- [x] iPhone 17 Simulator で light mode 起動 screenshot
- [x] iPhone 17 Simulator で dark mode 起動 screenshot
- [x] Settings 画面に Version / Build 表示が無いこと目視確認
- [x] reloadIcon / settingIcon が light / dark の両方で視認可能なこと目視確認

Closes #26
Closes #27

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: PR URL を user に返却**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr view --web 2>&1 | tail -3 || gh pr view --json url --jq .url
```

- [ ] **Step 5: PR に screenshot 4 枚を添付 (manual)**

`gh` CLI には画像 inline attach 機能が無いため、以下の手順で GitHub web UI から添付する:

1. `open "$(gh pr view --json url --jq .url)"` で PR を Web で開く
2. PR description の編集モードに入る (Edit ボタン)
3. 4 枚の screenshot (/tmp/leaftimer-issue-26-27-*.png) を description の "## Screenshots" セクションに drag & drop で attach
4. 添付後の markdown を整える:
   ```markdown
   ## Screenshots
   ### TimerView
   Light: <attached image>
   Dark: <attached image>
   ### Settings (Issue #27 後)
   Light: <attached image>
   Dark: <attached image>
   ```
5. Save

または `gh pr comment` で同様の image-attach コメントを別途追加してもよい。

注意: SendUserFile ツールで screenshot をユーザーに送ることもできる。CI fail にはならないため、添付忘れがあっても後追い可能。

---

## 実装後の動作確認チェックリスト

PR open 後、reviewer が:
- [ ] light mode で TimerView を見て、reloadIcon / settingIcon / タイマー文字が見える
- [ ] dark mode で TimerView を見て、reloadIcon / settingIcon / タイマー文字が見える
- [ ] Settings 画面で Version / Build 表示が無い
- [ ] make unit-tests が pass する

## Out-of-scope (本 PR では触らない)

- ViewModel `getColor1`〜`getColor4` の dark mode 対応 (CircleButton の visual)
- splashIcon の dark variant
- SessionStatsView / TimerControlsView の dead code 削除 or wire-up
- 全 hardcoded 色を design token へ統一する大規模 refactor

これらは別 issue で扱う候補。triage 段階で issue 化を検討。
