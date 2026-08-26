# 小粒クリーンアップ 3 本 (#66 / #85 / #70) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 3 つの独立した小粒 issue (ツールバーアイコンの SF Symbols 統一 / README への Claude workflow 用途追記 / コード衛生 minor cleanup まとめ) を、振る舞い不変のまま 3 本の PR で回収する。

**Architecture:** 各 issue は互いに依存しないため、**master から順次 3 本のブランチ**を切って 1 issue = 1 PR とする。この plan doc は最初のブランチ (`feature/66-sf-symbols-toolbar`) の第 1 commit に含め、PR #1 マージ後は master 上から後続 PR が参照する。#70 だけは 7+2 個のサブ項目を持つため 1 PR 内を 5 タスクに分割し、タスクごとに commit する。

**Tech Stack:** Swift 5 / SwiftUI / iOS 17.0 deployment target / XCTest + Quick + Nimble + ViewInspector / CocoaPods / SwiftLint / SwiftFormat / Xcode Cloud

**Spec:** GitHub Issues が spec を兼ねる。着手前に必ず 3 件とも読むこと:
- `gh issue view 66` — ツールバーアイコンを SF Symbols に統一する
- `gh issue view 85` — claude.yml (@claude PR アシスタント) の要否判断と Pods deny パターンの検証
- `gh issue view 70` — コード衛生 minor cleanup まとめ (**本文の 7 項目 + es0612 の 2026-08-23 コメントの 3 項目**)

## Global Constraints

これらは全タスクの要件に暗黙的に含まれる。違反したら即やり直し。

- **リポジトリの default branch は `master`** (`main` ではない)。`git checkout main` は失敗する。
- **ビルド/テストコマンドは毎回 `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を同一コマンド内に前置する。** 直前ターンの cwd に依存しない。
- **成否は exit code でなく出力マーカーで判定する。** 成功 = `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` が存在し、かつ `** TEST FAILED **` / `Error 6x` / `No rule to make target` が存在しないこと。両条件を満たさなければ失敗扱い。
- **`make unit-tests` / `make tests` を実行する Bash 呼び出しは timeout を 600000 (10 分) に設定する。** デフォルト 2 分では足りない。
- **shell は zsh。** `${PIPESTATUS[0]}` は無効。`set -o pipefail` を前置するか `${pipestatus[1]}` (小文字・1-indexed) を使う。`grep --include="*.swift"` の glob は必ずクォートする。
- **shell 変数は Bash 呼び出しをまたいで保持されない。** Simulator を触るブロックは、毎回そのコマンド内で UDID を解決する 1 行を先頭に置くこと。`$SIM` を前のブロックから引き継げると思ってはいけない:

  ```bash
  SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}')
  ```

  `grep "iPhone 17 ("` の末尾の `(` は必須 (無いと "iPhone 17 Pro" にも部分一致する)。以降の Simulator ブロックはこの 1 行を `&& \` で繋いだ同一コマンド内に含める。
- **新規 Swift ファイルを追加した commit には `make sort` の結果 (pbxproj の children ソート) を同じ commit に含める。** 後送りにすると review で必ず指摘される。
- **SwiftLint `empty_count`:** 新規コードは `.isEmpty` を使う。
- **振る舞いは一切変えない。** 3 issue とも「可読性・保守性・衛生」のみが目的。ユーザー可視の挙動が変わる変更を見つけたらそこで止めて報告する。
- **UserDefaults の永続化キー文字列は絶対に変えない。** 変えると既存ユーザーの設定がリセットされる。
- **破壊的操作 (ファイル削除 / `rm` / `git reset`) は、ユーザー自身の発言に対象ファイル名が出るまで実行しない。** 本 plan では Task 1 Step 8 が該当する。
- **push / `gh pr create` の前に `git fetch && gh pr list --state all --head <branch>` で既存 PR を確認する。**
- **CI 待ちは `gh run watch <run-id> --interval 30` をフォアグラウンドで実行する。** `gh pr checks --watch` やポーリングは使わない (この環境では sleep が無効で偽 pass を掴む)。
- **merge は `gh pr checks <PR> && gh pr merge <PR> --merge` の同一チェーンで実行する。** このリポジトリは Auto-merge 無効。非同期通知を merge の根拠にしない。

---

## File Structure

### PR #1 — Issue #66 (`feature/66-sf-symbols-toolbar`)

| ファイル | 役割 | 変更内容 |
| --- | --- | --- |
| `docs/superpowers/plans/2026-08-26-minor-cleanup-bundle-66-85-70.md` | 本 plan | 新規 (第 1 commit) |
| `app/LeafTimer/View/TimerView.swift:130,147` | トップ画面のツールバー | `Image("reloadIcon")` / `Image("settingIcon")` を `Image(systemName:)` に置換 |
| `app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset/` | 旧 PDF アセット | 削除候補 (**ユーザー承認が必要**) |
| `app/LeafTimer/App/Assets.xcassets/settingIcon.imageset/` | 旧 PDF アセット | 削除候補 (**ユーザー承認が必要**) |

### PR #2 — Issue #85 (`feature/85-readme-claude-workflows`)

| ファイル | 役割 | 変更内容 |
| --- | --- | --- |
| `README.md` | リポジトリ入口 | Claude workflow 2 本の用途を記載するセクションを追加 |

### PR #3 — Issue #70 (`feature/70-code-hygiene-cleanup`)

| ファイル | 役割 | 変更内容 |
| --- | --- | --- |
| `app/LeafTimer/Components/AppLogger.swift` | **新規** — `os.Logger` の共有定義 | 作成 + pbxproj 配線 |
| `app/LeafTimer.xcodeproj/project.pbxproj` | Xcode プロジェクト | `AppLogger.swift` を app target に追加 + `make sort` |
| `app/LeafTimer/Components/DefaultAudioManager.swift` | 音声管理 | `print()` 7 箇所 → `AppLogger.audio.error(...)` |
| `app/LeafTimer/Components/DefaultNotificationScheduler.swift` | 通知予約 | `print()` 1 箇所 → `AppLogger.notification.error(...)` |
| `app/LeafTimer/View/Settings/SoundSettingsSection.swift` | 設定画面 | `print()` 1 箇所 → `AppLogger.audio.error(...)` |
| `app/LeafTimer/View/Elements/GIFPlayerView.swift` | GIF 実体 (UIKit) | `print()` 6 箇所 → `AppLogger.gif.error(...)` |
| `app/LeafTimer/Components/LocalUserDefaultWrapper.swift:16,27` | UserDefaults ラッパー | `synchronize()` 2 箇所を削除 |
| `app/LeafTimer/Components/UserDefaultItem.swift` | 永続化キー enum | `case hasLaunchedBefore` を追加 |
| `app/LeafTimer/ViewModel/TimerViewModel.swift:82,85` | メイン VM | 生文字列 `"hasLaunchedBefore"` → `UserDefaultItem.hasLaunchedBefore.rawValue` |
| `app/LeafTimer/Info.plist:270-273` | Info.plist | `UIRequiredDeviceCapabilities` (armv7) を削除 |
| `app/LeafTimer/App/AppDelegate.swift:11,12,27,31,60` | アプリ起動 | 未使用宣言削除 / force unwrap 解消 / wrapper 共有 |
| `app/LeafTimer/Components/StoreKitReviewRequester.swift:16` | レビュー要求 | `SKStoreReviewController.requestReview(in:)` → `AppStore.requestReview(in:)` |
| `app/LeafTimer/View/TimerView.swift:174-197` | トップ画面 | `leafLayer` の実質デッド Optional を解消 |
| `app/LeafTimer/View/Elements/CircleButton.swift:32-48` | 開始/停止ボタン | 内側円比率リテラルを `innerRatios` に集約 |
| `app/LeafTimerTests/CircleButtonRatioTests.swift` | **新規テスト** | `innerRatios` の値を固定するテスト + pbxproj 配線 |
| `app/LeafTimerTests/OnboardingGateTests.swift` | 既存テスト | 初回起動キーのテストを追加 |

### 本 plan のスコープ外 (明示的な defer)

- **#70 コメント項目 3「ModernTimerViewSpec の index ベース ViewInspector パス」** — issue コメント自身が「xit 群整理のタイミングでまとめて」と述べており、対象の 2 件は既に `xit` (Issue #16 で無効化済み) のため今回のスコープに含めない。PR #3 の本文にこの defer を明記する。
- **#70 本文項目「AdsView.swift:9 の広告ユニット ID を print」** — 2026-08-26 時点で `AdsView.swift` に `print()` は 1 件も存在しない (現在は `AdsBootstrapper` 経由の実装に置き換わっており、ユニット ID は `KeyManager().getAdUnitID()` から直接 banner に渡されるのみ)。**既に解消済み**として PR 本文で報告し、コード変更はしない。

---

## Task 1: Issue #66 — ツールバーアイコンを SF Symbols に統一する

**Files:**
- Create: `docs/superpowers/plans/2026-08-26-minor-cleanup-bundle-66-85-70.md` (この plan 自身)
- Modify: `app/LeafTimer/View/TimerView.swift:130`, `app/LeafTimer/View/TimerView.swift:147`
- Delete (要承認): `app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset/`, `app/LeafTimer/App/Assets.xcassets/settingIcon.imageset/`
- Test: 自動テストなし (下記「なぜテストを書かないか」参照)

**Interfaces:**
- Consumes: なし (このタスクが最初)
- Produces: なし (後続タスクは TimerView のツールバーに依存しない)

**背景 (実地確認済み):**
`TimerView.swift` のツールバーは 3 ボタン構成。中央の履歴ボタンだけが既に `Image(systemName: "chart.bar.fill")` で、両脇の 2 つがカスタム PDF アセットのまま。アプリの他画面 (`HistoryView` / `EnhancedSettingView` / `Settings/*`) は全て `systemName:` を使っており、この 2 つだけが例外。両アセットは `template-rendering-intent: template` で `.foregroundColor(.primary)` により単色描画されているため、SF Symbols への差し替えで**色の扱いは変わらない**。

**採用するシンボル:**

| 現在 | 置換後 | 理由 |
| --- | --- | --- |
| `Image("reloadIcon")` | `Image(systemName: "arrow.counterclockwise")` | 「タイマーをリセット」= iOS 純正時計アプリのリセットと同じ反時計回り矢印。`accessibilityLabel` も `timer.a11y.reset` で「リセット」を指しており意味が一致する |
| `Image("settingIcon")` | `Image(systemName: "gearshape.fill")` | 設定の標準シンボル。同画面の `chart.bar.fill` / `leaf.fill` / `flame.fill` が `.fill` 系のため weight 感を揃える |

**なぜ自動テストを書かないか (意図的な判断):**
ツールバーの ViewInspector テストは `ModernTimerViewSpec.swift:99,110` で既に `xit` 無効化済み (Issue #16 で index ベースのパスが壊れたまま)。ここに新規 index ベーステストを足すのは、本 plan がスコープ外と宣言した「index パス脆弱性」を増やす行為で逆効果。よって**検証は「既存テスト全 green の維持」+「Simulator 目視 (light/dark 2 状態)」で行う**。これは CLAUDE.md ルール 31 のトップ画面 overlay 検証手順に沿う。

- [ ] **Step 1: ブランチを作成し、この plan doc を第 1 commit にする**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git fetch origin && \
git checkout master && git pull --ff-only && \
git checkout -b feature/66-sf-symbols-toolbar && \
git add docs/superpowers/plans/2026-08-26-minor-cleanup-bundle-66-85-70.md && \
git commit -m "docs(plan): 小粒クリーンアップ 3 本 (#66/#85/#70) の実装計画を追加"
```

期待: `1 file changed` を含む commit が 1 つ作られる。

- [ ] **Step 2: 変更前のベースラインスクリーンショットを撮る**

CLAUDE.md ルール 30 に従い、`find app/build` は使わずビルド設定から実パスを取得する。UDID は毎ブロック同一コマンド内で解決する (Global Constraints 参照)。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
echo "SIM=$SIM" && \
xcrun simctl boot "$SIM" 2>/dev/null; \
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,id=$SIM" build 2>&1 | tail -5
```

期待: `SIM=` の後に 36 文字の UDID が出て、`** BUILD SUCCEEDED **` で終わる。次に実パスを取得して install/launch する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
BUILT=$(xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,id=$SIM" -showBuildSettings 2>/dev/null \
  | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //') && \
echo "$BUILT" && \
applesimutils --byId "$SIM" --bundle jp.ema.LeafTimer --setPermissions "userTracking=YES" --restartSB ; \
xcrun simctl install "$SIM" "$BUILT/LeafTimer.app" && \
xcrun simctl spawn "$SIM" defaults write jp.ema.LeafTimer hasSeenOnboarding -bool true && \
xcrun simctl ui "$SIM" appearance light && \
xcrun simctl launch "$SIM" jp.ema.LeafTimer
```

数秒おいてから撮影 (CLAUDE.md ルール 32: 復帰直後の 1 枚目は遷移アニメ中の旧フレームを掴む):

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
xcrun simctl io "$SIM" screenshot /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/scratch-66-before-light.png && \
xcrun simctl ui "$SIM" appearance dark && \
xcrun simctl io "$SIM" screenshot /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/scratch-66-before-dark.png
```

2 枚を Read して、左上のリロードアイコンと右上の歯車アイコンが見えていることを確認する。

- [ ] **Step 3: TimerView.swift のリセットボタンを SF Symbol に置換**

`app/LeafTimer/View/TimerView.swift:130` を置換する。変更前:

```swift
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: didTapResetButton) {
                                Image("reloadIcon").foregroundColor(.primary)
                            }
                            .accessibilityLabel(NSLocalizedString("timer.a11y.reset", comment: "Reset timer button"))
                        }
```

変更後:

```swift
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: didTapResetButton) {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.primary)
                            }
                            .accessibilityLabel(NSLocalizedString("timer.a11y.reset", comment: "Reset timer button"))
                        }
```

- [ ] **Step 4: TimerView.swift の設定ボタンを SF Symbol に置換**

`app/LeafTimer/View/TimerView.swift:147` を置換する。変更前:

```swift
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: EnhancedSettingView(settingViewModel: settingViewModel)) {
                                Image("settingIcon").foregroundColor(.primary)
                            }
                            .accessibilityLabel(NSLocalizedString("timer.a11y.settings", comment: "Settings button"))
                        }
```

変更後:

```swift
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: EnhancedSettingView(settingViewModel: settingViewModel)) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.primary)
                            }
                            .accessibilityLabel(NSLocalizedString("timer.a11y.settings", comment: "Settings button"))
                        }
```

- [ ] **Step 5: 旧アセットへの参照が 0 件になったことを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
grep -rn "reloadIcon\|settingIcon" --include="*.swift" . | grep -v Pods
```

期待: **何も出力されない**。zsh では 0 件時に `grep` は exit 1 を返すだけで `no matches found` は出ない (`--include` の glob をクォートしているため)。もし何か出たら置換漏れ。

- [ ] **Step 6: フルテストを実行する**

Bash timeout を **600000** に設定して実行する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

期待: 出力に `** TEST SUCCEEDED **` が含まれ、`** TEST FAILED **` / `Error 6` / `No rule to make target` が含まれないこと。両方を目で確認する。

- [ ] **Step 7: Simulator で light / dark 2 状態を目視検証する**

Step 2 と同じ手順でリビルド・再インストールし、変更後のスクリーンショットを撮る。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,id=$SIM" build 2>&1 | tail -3 && \
BUILT=$(xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,id=$SIM" -showBuildSettings 2>/dev/null \
  | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //') && \
xcrun simctl install "$SIM" "$BUILT/LeafTimer.app" && \
xcrun simctl ui "$SIM" appearance light && \
xcrun simctl launch "$SIM" jp.ema.LeafTimer
```

数秒おいてから:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
xcrun simctl io "$SIM" screenshot /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/scratch-66-after-light.png && \
xcrun simctl ui "$SIM" appearance dark && \
xcrun simctl io "$SIM" screenshot /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/scratch-66-after-dark.png
```

4 枚 (before/after × light/dark) を Read して以下を確認する:

1. 左上が反時計回り矢印、右上が塗りつぶし歯車になっている
2. light / dark どちらでもアイコンが背景に埋もれず読める (`.primary` が効いている)
3. 中央の `chart.bar.fill` と線の太さ・サイズ感が揃っている
4. アイコンの位置・タップ領域が before から動いていない

「既存デザインか回帰か」に迷ったら `docs/ver1_2/screen/` の旧ストア掲載スクショと突き合わせる (CLAUDE.md ルール 42)。

スクリーンショットは `SendUserFile` でユーザーに渡す (PR 本文にローカルパスの画像は埋め込めない — ルール 25)。

- [ ] **Step 8: 旧 PDF アセットの削除可否をユーザーに確認する**

**このステップは破壊的操作 (ファイル削除) を含むため、自走で実行してはならない (CLAUDE.md ルール 14)。**

`AskUserQuestion` で以下を聞く:

- 質問: 「SF Symbols 化で参照 0 件になった旧アイコンアセットをどうしますか？」
- 選択肢 A: 「この PR で削除する」 — 承認を得たら、ユーザー自身に `! rm -rf app/LeafTimer/App/Assets.xcassets/reloadIcon.imageset app/LeafTimer/App/Assets.xcassets/settingIcon.imageset` を実行してもらう (選択肢の承認だけでは authorization にならないため、ファイル名がユーザーの turn に出る形にする)
- 選択肢 B: 「残す (Recommended)」 — アセットは folder reference 配下で pbxproj に個別登録されておらず、残しても実害は数 KB のみ。削除は別途 #74 (docs/ver1_2 整理) と束ねる

**B が選ばれた場合は削除せず Step 9 へ進む。** どちらの場合も PR 本文に判断と理由を記載する。

- [ ] **Step 9: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/LeafTimer/View/TimerView.swift && \
git commit -m "refactor(#66): ツールバーのリセット/設定アイコンを SF Symbols に統一

- reloadIcon (PDF) -> arrow.counterclockwise
- settingIcon (PDF) -> gearshape.fill
- 既に systemName の chart.bar.fill と合わせ、トップ画面のツールバー 3 ボタンが全て SF Symbols になる
- template アセット + .primary から SF Symbol + .primary への差し替えのため描画色の扱いは不変"
```

Step 8 で削除を選んだ場合は `git add -A app/LeafTimer/App/Assets.xcassets` も同 commit に含める。

- [ ] **Step 10: push して PR を作成する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git fetch && gh pr list --state all --head feature/66-sf-symbols-toolbar
```

既存 PR が無いことを確認してから:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git push -u origin feature/66-sf-symbols-toolbar && \
gh pr create --base master --title "refactor: #66 ツールバーアイコンを SF Symbols に統一" --body "$(cat <<'EOF'
## 概要
トップ画面 (`TimerView`) のツールバー 3 ボタンのうち、カスタム PDF アセットのまま残っていた 2 つを SF Symbols に統一しました。

| ボタン | 変更前 | 変更後 |
| --- | --- | --- |
| リセット (左) | `Image("reloadIcon")` (PDF) | `Image(systemName: "arrow.counterclockwise")` |
| 履歴 (中) | `Image(systemName: "chart.bar.fill")` | 変更なし |
| 設定 (右) | `Image("settingIcon")` (PDF) | `Image(systemName: "gearshape.fill")` |

## 検証
- `make tests` green (`** TEST SUCCEEDED **`)
- Simulator (iPhone 17) で light / dark の 2 状態を before/after 比較。アイコンが背景に埋もれず、中央の `chart.bar.fill` と weight 感が揃っていることを確認
- 旧アセットは `template-rendering-intent: template` + `.foregroundColor(.primary)` だったため、描画色の扱いは変更前後で不変

## 備考
- 実装計画: `docs/superpowers/plans/2026-08-26-minor-cleanup-bundle-66-85-70.md` (#66/#85/#70 の 3 本立て。本 PR はその 1 本目)
- ツールバーの ViewInspector テストは `ModernTimerViewSpec.swift` で Issue #16 以来 `xit` 無効化されているため、本 PR では新規テストを追加せず既存テスト全 green + Simulator 目視で検証しています

Closes #66

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01FhYNKDgBJ6MqpYG6fYJYv8
EOF
)"
```

- [ ] **Step 11: CI を待って merge する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr checks <PR番号>
```

出力の URL 末尾から run ID を取り、run ごとにフォアグラウンドで watch する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh run watch <run-id> --interval 30
```

全 run 完了後、**同一チェーンで**再検証してから merge する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
gh pr checks <PR番号> && gh pr merge <PR番号> --merge
```

---

## Task 2: Issue #85 — README に Claude workflow 2 本の用途を追記する

**Files:**
- Modify: `README.md`
- Test: なし (ドキュメントのみ)

**Interfaces:**
- Consumes: なし
- Produces: なし

**背景 (実地確認済み):**
Issue #85 の 2 つのチェックボックスのうち、**調査部分は 2026-07-06 の bot コメントで既に決着している**:

1. `.claude/settings.json` の `Read(/app/Pods/**)` deny パターンは実マッチを検証済みで**正しく動作する** (`app/Pods/**` はネスト含めブロック、`app/Podfile` は誤ブロックなし)。→ **修正不要。コード変更なし。**
2. `claude.yml` は壊れておらず、`@claude` メンション起動用として `claude-code-review.yml` (PR 自動レビュー) と役割が異なる。→ **削除せず維持。**

残る作業は「用途が分かるよう README に 1 行ずつ追記する」だけ。bot はこれを `claude/issue-85-20260706-0002` ブランチで実施したが **PR は作られず放置されている** (2026-08-26 時点の `README.md` に該当記述なし)。

**7 週間 stale なそのブランチは使わない。** master から新規に書き直す。理由: (a) その間に `.github/workflows/pr-tests.yml` を含むリポジトリ構成が変化している可能性がある、(b) 現行 README の文脈に合わせて書いたほうが短く済む。

- [ ] **Step 1: ブランチを作成する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git fetch origin && \
git checkout master && git pull --ff-only && \
git checkout -b feature/85-readme-claude-workflows
```

- [ ] **Step 2: 現在の workflow 3 本の実体を確認する**

推測で書かず、実ファイルの `name:` と `on:` トリガを 1 回見る (CLAUDE.md ルール 7)。

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
for f in .github/workflows/*.yml; do echo "=== $f ==="; sed -n '1,25p' "$f"; done
```

出力から各 workflow の起動条件を読み取り、Step 3 の記述が実体と一致しているか照合する。**一致しない場合は Step 3 の文言を実体に合わせて直すこと。**

- [ ] **Step 3: README.md に CI / Claude workflow セクションを追加する**

現在の `README.md` は以下の内容 (全文):

```markdown
# LeafTimer

簡易機能のタイマーアプリ


## Description

下記の機能を実装する
- 作業、休憩時間のタイマー機能
- 各種設定
- モード変更


## Requirement

chack cocoaPod file

## Licence

Copyright 2025 by Author


## Author

AsaPapaLab.
```

`## Requirement` セクションの直後、`## Licence` の直前に以下を挿入する:

```markdown
## GitHub Actions

| Workflow | 起動条件 | 用途 |
| --- | --- | --- |
| `.github/workflows/pr-tests.yml` | PR 作成・更新時 | ユニットテストを実行する CI |
| `.github/workflows/claude-code-review.yml` | PR 作成・更新時 | Claude による自動コードレビュー (常時稼働) |
| `.github/workflows/claude.yml` | Issue / PR コメントで `@claude` とメンションした時 | Claude を対話的に呼び出して調査・修正させる。メンションが無い限り skip されるため、run 履歴が skipped 続きでも異常ではない |

配布ビルド (TestFlight / App Store) は GitHub Actions ではなく **Xcode Cloud** が担当する。
```

**Step 2 の実出力と食い違う記述があればそちらを正とする。**

- [ ] **Step 4: 記述が実体と一致していることを再確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
ls .github/workflows/ && \
grep -n "claude.yml\|claude-code-review.yml\|pr-tests.yml" README.md
```

期待: `ls` に出た 3 ファイルすべてが README の表に 1 行ずつ存在する。README に無い workflow / 実在しない workflow への言及があれば直す。

- [ ] **Step 5: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add README.md && \
git commit -m "docs(#85): README に GitHub Actions 3 本の用途を追記

- pr-tests.yml / claude-code-review.yml / claude.yml の起動条件と役割を表で整理
- claude.yml が skipped 続きでも異常ではない旨を明記 (#85 の発端)
- 配布は Xcode Cloud 担当であることを併記"
```

- [ ] **Step 6: push して PR を作成する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git fetch && gh pr list --state all --head feature/85-readme-claude-workflows
```

既存 PR が無いことを確認してから:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git push -u origin feature/85-readme-claude-workflows && \
gh pr create --base master --title "docs: #85 README に GitHub Actions の用途を追記" --body "$(cat <<'EOF'
## 概要
Issue #85 の 2 つのチェックボックスのうち、調査部分は 2026-07-06 のコメントで既に決着済みです。本 PR は残作業である README への用途記載のみを行います。

| #85 のチェック項目 | 結論 | 本 PR での対応 |
| --- | --- | --- |
| `claude.yml` の要否判断 | メンション起動用として維持 (run が skipped 続きなのは正常) | README に用途を記載 |
| `Read(/app/Pods/**)` deny パターンの検証 | 実マッチ検証済み・正しく動作 (`app/Pods/**` はネスト含めブロック、`app/Podfile` は誤ブロックなし) | **修正不要のためコード変更なし** |

## 変更内容
`README.md` に `## GitHub Actions` セクションを追加し、workflow 3 本 (`pr-tests.yml` / `claude-code-review.yml` / `claude.yml`) の起動条件と用途を表で整理しました。配布ビルドが Xcode Cloud 担当である旨も併記しています。

## 備考
- 2026-07-06 に bot が作った `claude/issue-85-20260706-0002` ブランチは 7 週間 stale のため使わず、master から書き直しました
- 実装計画: `docs/superpowers/plans/2026-08-26-minor-cleanup-bundle-66-85-70.md` (3 本立ての 2 本目)

Closes #85

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01FhYNKDgBJ6MqpYG6fYJYv8
EOF
)"
```

- [ ] **Step 7: CI を待って merge する**

Task 1 Step 11 と同じ手順 (`gh pr checks` → `gh run watch <run-id> --interval 30` → `gh pr checks <PR> && gh pr merge <PR> --merge`)。

---

## Task 3: Issue #70-a — `os.Logger` を導入して本番コードの `print()` を置換する

**Files:**
- Create: `app/LeafTimer/Components/AppLogger.swift`
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj` (新規ファイル配線 + `make sort`)
- Modify: `app/LeafTimer/Components/DefaultAudioManager.swift:32,88,98,117,126,139,149`
- Modify: `app/LeafTimer/Components/DefaultNotificationScheduler.swift:53`
- Modify: `app/LeafTimer/View/Settings/SoundSettingsSection.swift:128`
- Modify: `app/LeafTimer/View/Elements/GIFPlayerView.swift:72,82,88,100,106,117`
- Test: 新規テストなし。既存の `AudioSystemVerificationTests` / `GIFPlayerViewTests` / `NotificationChainBuilderTests` が回帰ガードになる

**Interfaces:**
- Consumes: なし
- Produces: `enum AppLogger` — `static let audio: Logger`, `static let notification: Logger`, `static let gif: Logger`。Task 4 以降でも必要になれば同じ enum に category を足す。

**背景 (実地確認済み):**
本番コードに `print()` が 15 箇所ある。すべてエラーパスの診断ログで、`os.Logger` 化が適切 (削除すると障害調査手段が消える)。issue 本文が挙げていた `AdsView.swift:9` の広告ユニット ID 出力は**既に解消済み** — 現行 `AdsView.swift` に `print()` は 1 件も無い。この事実は PR 本文で報告する。

現時点でリポジトリに `os.Logger` の利用実績はゼロ (`grep "import os"` が 0 件) なので、共有定義を 1 ファイル新設する。

- [ ] **Step 1: ブランチを作成する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git fetch origin && \
git checkout master && git pull --ff-only && \
git checkout -b feature/70-code-hygiene-cleanup
```

- [ ] **Step 2: `AppLogger.swift` を作成する**

`app/LeafTimer/Components/AppLogger.swift` を新規作成する:

```swift
import Foundation
import os

/// Issue #70: 本番コードに散在していた `print()` の置き換え先。
/// `os.Logger` は Console.app / `xcrun simctl spawn <UDID> log stream` から
/// subsystem + category で絞り込めるため、リリースビルドでも診断できる。
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "jp.ema.LeafTimer"

    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let notification = Logger(subsystem: subsystem, category: "notification")
    static let gif = Logger(subsystem: subsystem, category: "gif")
}
```

- [ ] **Step 3: `AppLogger.swift` を Xcode の app target に配線する**

`app/LeafTimer.xcodeproj/project.pbxproj` を手で編集する。既存の `Components/` 配下ファイル (例: `UserDefaultItem.swift`) がどう登録されているかを先に見る:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
grep -n "UserDefaultItem.swift" LeafTimer.xcodeproj/project.pbxproj
```

出力される 4 種類の登場箇所すべてに `AppLogger.swift` の対応行を追加する:

1. `PBXBuildFile` セクション — `XXXXXXXX /* AppLogger.swift in Sources */ = {isa = PBXBuildFile; fileRef = YYYYYYYY /* AppLogger.swift */; };`
2. `PBXFileReference` セクション — `YYYYYYYY /* AppLogger.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppLogger.swift; sourceTree = "<group>"; };`
3. `Components` グループの `children` 配列 — `YYYYYYYY /* AppLogger.swift */,`
4. app target の `PBXSourcesBuildPhase` の `files` 配列 — `XXXXXXXX /* AppLogger.swift in Sources */,`

`XXXXXXXX` / `YYYYYYYY` は既存 ID と衝突しない 24 桁の 16 進 ID を新規に作る (既存 ID を `grep` して未使用であることを確認すること)。

- [ ] **Step 4: pbxproj をソートし、orphan が無いことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make sort && make precheck 2>&1 | tail -20
```

期待: precheck が `AppLogger.swift` を orphan (target 未 attach) として報告**しない**こと。orphan と出たら Step 3 の項目 4 (Sources build phase) が漏れている。

- [ ] **Step 5: ビルドが通ることを確認する (`print` 置換前)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" build 2>&1 | tail -5
```

期待: `** BUILD SUCCEEDED **` があり `Error 6` が無い。ここで通れば配線は正しい。

- [ ] **Step 6: `DefaultAudioManager.swift` の `print()` 7 箇所を置換する**

ファイル先頭の import に `os` は不要 (`AppLogger` 経由のため)。7 箇所を以下の対応で置換する:

| 行 | 変更前 | 変更後 |
| --- | --- | --- |
| 32 | `print("Failed to setup audio session: \(error)")` | `AppLogger.audio.error("Failed to setup audio session: \(error.localizedDescription, privacy: .public)")` |
| 88 | `print("Warning: Could not find warning1.mp3")` | `AppLogger.audio.warning("Could not find warning1.mp3")` |
| 98 | `print("Failed to setup stop audio: \(error)")` | `AppLogger.audio.error("Failed to setup stop audio: \(error.localizedDescription, privacy: .public)")` |
| 117 | `print("Failed to setup working audio: \(error)")` | `AppLogger.audio.error("Failed to setup working audio: \(error.localizedDescription, privacy: .public)")` |
| 126 | `print("Failed to activate audio session: \(error)")` | `AppLogger.audio.error("Failed to activate audio session: \(error.localizedDescription, privacy: .public)")` |
| 139 | `print("Failed to deactivate audio session: \(error)")` | `AppLogger.audio.error("Failed to deactivate audio session: \(error.localizedDescription, privacy: .public)")` |
| 149 | `print("Failed to deactivate audio session in deinit: \(error)")` | `AppLogger.audio.error("Failed to deactivate audio session in deinit: \(error.localizedDescription, privacy: .public)")` |

行番号は編集で動くので、**必ず変更前の文字列で一意にマッチさせて置換する** (行 98/117 は文言が異なるので一意)。

`privacy: .public` を明示する理由: `os.Logger` の文字列補間はデフォルトで `private` 扱いとなり、実機の log stream で `<private>` にマスクされて調査に使えなくなるため。ここで出るのは OS のエラー記述のみで個人情報を含まない。

- [ ] **Step 7: 残り 3 ファイルの `print()` 8 箇所を置換する**

`app/LeafTimer/Components/DefaultNotificationScheduler.swift:53`:

```swift
                    AppLogger.notification.error("notification add failed - \(error.localizedDescription, privacy: .public)")
```

(元の `"LeafTimer: notification add failed - \(error)"` の `LeafTimer: ` プレフィックスは subsystem が担うので落とす)

`app/LeafTimer/View/Settings/SoundSettingsSection.swift:128`:

```swift
                    AppLogger.audio.error("Error playing sound: \(error.localizedDescription, privacy: .public)")
```

`app/LeafTimer/View/Elements/GIFPlayerView.swift` の 6 箇所:

| 行 | 変更前 | 変更後 |
| --- | --- | --- |
| 72 | `print("SwiftGif: Source for the image does not exist")` | `AppLogger.gif.error("Source for the image does not exist")` |
| 82 | `print("SwiftGif: This image named \"\(url)\" does not exist")` | `AppLogger.gif.error("Image at url does not exist: \(url, privacy: .public)")` |
| 88 | `print("SwiftGif: Cannot turn image named \"\(url)\" into NSData")` | `AppLogger.gif.error("Cannot turn image at url into NSData: \(url, privacy: .public)")` |
| 100 | `print("SwiftGif: This image named \"\(name)\" does not exist")` | `AppLogger.gif.error("Image named does not exist: \(name, privacy: .public)")` |
| 106 | `print("SwiftGif: Cannot turn image named \"\(name)\" into NSData")` | `AppLogger.gif.error("Cannot turn image named into NSData: \(name, privacy: .public)")` |
| 117 | `print("SwiftGif: Cannot turn image named \"\(asset)\" into NSDataAsset")` | `AppLogger.gif.error("Cannot turn image named into NSDataAsset: \(asset, privacy: .public)")` |

補間する `url` / `name` / `asset` が `String` 型でなければ `\(String(describing: url), privacy: .public)` に直す。ビルドエラーが出たらこちらを使う。

- [ ] **Step 8: 本番コードから `print()` が消えたことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
grep -rn "print(" --include="*.swift" LeafTimer | grep -v Tests
```

期待: **何も出力されない**。1 件でも残っていたら置換漏れ。

- [ ] **Step 9: フルテストを実行する**

Bash timeout を **600000** に設定する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

期待: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` / `Error 6` / `No rule to make target` なし。

- [ ] **Step 10: commit (`make sort` の結果を同 commit に含める)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/LeafTimer/Components/AppLogger.swift \
        app/LeafTimer.xcodeproj/project.pbxproj \
        app/LeafTimer/Components/DefaultAudioManager.swift \
        app/LeafTimer/Components/DefaultNotificationScheduler.swift \
        app/LeafTimer/View/Settings/SoundSettingsSection.swift \
        app/LeafTimer/View/Elements/GIFPlayerView.swift && \
git commit -m "refactor(#70): 本番コードの print() 15 箇所を os.Logger に置換

- AppLogger.swift を新設し subsystem=bundleID / category=audio,notification,gif で分類
- リリースビルドでも Console.app / log stream から診断できるようにする
- 補間値には privacy: .public を明示 (既定の private だと <private> にマスクされ調査不能)
- pbxproj への配線と make sort を同 commit に含める"
```

`git status --short` で pbxproj 以外に想定外の差分が出ていないことを確認する。

---

## Task 4: Issue #70-b — UserDefaults まわりの衛生 (`synchronize()` 削除 + 生文字列キーの enum 化)

**Files:**
- Modify: `app/LeafTimer/Components/LocalUserDefaultWrapper.swift:16,27`
- Modify: `app/LeafTimer/Components/UserDefaultItem.swift:14`
- Modify: `app/LeafTimer/ViewModel/TimerViewModel.swift:82,85`
- Test: `app/LeafTimerTests/OnboardingGateTests.swift` (テスト追加)

**Interfaces:**
- Consumes: なし
- Produces: `UserDefaultItem.hasLaunchedBefore` (rawValue は既存キーと同一の `"hasLaunchedBefore"`)

**背景 (実地確認済み):**
- `LocalUserDefaultsWrapper` の `synchronize()` は iOS 12 以降 deprecated かつ不要 (`UserDefaults` が自動で永続化する)。既存の `DataPersistenceTests` が save→load ラウンドトリップを検証しているため、削除後もそれが green なら回帰なし。
- `TimerViewModel.swift:82,85` の `"hasLaunchedBefore"` だけが `UserDefaultItem` enum を通さない生文字列。同じ初期化ブロック内の `workingSound` / `breakSound` は enum 経由で対照的。

**⚠️ 最重要の注意:** `UserDefaultItem` に追加する case 名は **必ず `hasLaunchedBefore`** とすること。`enum UserDefaultItem: String` は raw value を省略すると case 名がそのまま rawValue になるため、`hasLaunchedBefore` なら永続化キーは変わらず既存ユーザーに影響しない。別名 (`launchedBefore` 等) にすると**全既存ユーザーのサウンド設定が初回起動扱いで上書きされる**。

- [ ] **Step 1: 失敗するテストを書く (キーが enum 経由になることを固定する)**

`app/LeafTimerTests/OnboardingGateTests.swift` の末尾のクラス閉じ括弧の直前に以下を追加する:

```swift
    // MARK: - Issue #70: 初回起動キーの enum 化

    /// `hasLaunchedBefore` の永続化キーは既存ユーザーの設定を保つため
    /// 文字列 "hasLaunchedBefore" から変えてはならない。
    func testHasLaunchedBeforeRawValueIsUnchanged() {
        XCTAssertEqual(UserDefaultItem.hasLaunchedBefore.rawValue, "hasLaunchedBefore")
    }

    /// 初回起動時 (キー未設定) にサウンド既定値と初回フラグが
    /// すべて UserDefaultItem 経由のキーで書かれることを検証する。
    func testFirstLaunchWritesDefaultsUsingEnumKeys() {
        let wrapper = MockUserDefaultWrapper()
        wrapper.setValue(for: UserDefaultItem.hasLaunchedBefore.rawValue, value: 0)

        // notificationScheduler を Spy にするのは、既定の DefaultNotificationScheduler だと
        // init 内の cancelAll() が実 UNUserNotificationCenter に触れてしまうため。
        _ = TimerViewModel(
            timerManager: SpyTimerManager(),
            audioManager: SpyAudioManager(),
            userDefaultWrapper: wrapper,
            sessionStatsRepository: SpySessionStatsRepository(),
            notificationScheduler: SpyNotificationScheduler()
        )

        // UserDefaultsWrapper.loadData は戻り値型でオーバーロードされているため、
        // 型注釈付きの let で Int 版を明示的に選ぶ。
        let workingSound: Int = wrapper.loadData(key: UserDefaultItem.workingSound.rawValue)
        let breakSound: Int = wrapper.loadData(key: UserDefaultItem.breakSound.rawValue)
        let launchedFlag: Int = wrapper.loadData(key: UserDefaultItem.hasLaunchedBefore.rawValue)

        XCTAssertEqual(workingSound, 0)
        XCTAssertEqual(breakSound, 0)
        XCTAssertEqual(launchedFlag, 1)
    }
```

**確認済みの前提 (2026-08-26 時点):**
- `OnboardingGateTests.swift` は `final class OnboardingGateTests: XCTestCase` で、冒頭に `import XCTest` / `@testable import LeafTimer` の両方がある。そのまま追記できる。
- `TimerViewModel.init` の signature は `(timerManager:audioManager:userDefaultWrapper:sessionStatsRepository:reviewPolicy:reviewRequester:notificationScheduler:now:)` で、後ろ 4 つは既定値付き。
- `SpyTimerManager` / `SpyAudioManager` / `SpySessionStatsRepository` / `SpyNotificationScheduler` は `LeafTimerTests/` に実在する。

- [ ] **Step 2: テストが失敗することを確認する**

Bash timeout を **600000** に設定する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tail -30
```

期待: **コンパイルエラー** `type 'UserDefaultItem' has no member 'hasLaunchedBefore'` が出て `** TEST FAILED **` になること。この失敗理由が予測どおりであることを目で確認してから次へ進む (予測失敗値と実失敗値の突き合わせ)。別の理由で落ちている場合は Step 1 のテストコードを直す。

- [ ] **Step 3: `UserDefaultItem` に case を追加する**

`app/LeafTimer/Components/UserDefaultItem.swift` の enum を以下に変更する:

```swift
enum UserDefaultItem: String {
    case workingTime
    case breakTime
    case vibration

    case workingSound
    case breakSound

    case totalPomodoroCount
    case lastReviewRequestedCount

    case hasSeenOnboarding

    /// Issue #70: TimerViewModel が生文字列で参照していた初回起動フラグ。
    /// rawValue は既存ユーザーの永続化キーと一致させる必要があるため変更禁止。
    case hasLaunchedBefore
}
```

- [ ] **Step 4: `TimerViewModel` の生文字列を enum 経由に置換する**

`app/LeafTimer/ViewModel/TimerViewModel.swift:82-86` を置換する。変更前:

```swift
        // Set default sound settings on first launch only
        if userDefaultWrapper.loadData(key: "hasLaunchedBefore") == 0 {
            userDefaultWrapper.saveData(key: UserDefaultItem.workingSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: UserDefaultItem.breakSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: "hasLaunchedBefore", value: 1)
        }
```

変更後:

```swift
        // Set default sound settings on first launch only
        if userDefaultWrapper.loadData(key: UserDefaultItem.hasLaunchedBefore.rawValue) == 0 {
            userDefaultWrapper.saveData(key: UserDefaultItem.workingSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: UserDefaultItem.breakSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: UserDefaultItem.hasLaunchedBefore.rawValue, value: 1)
        }
```

- [ ] **Step 5: `synchronize()` 2 箇所を削除する**

`app/LeafTimer/Components/LocalUserDefaultWrapper.swift` を以下に変更する:

```swift
import Foundation

protocol UserDefaultsWrapper {
    func saveData(key: String, value: Int)
    func loadData(key: String) -> Int

    func saveData(key: String, value: Bool)
    func loadData(key: String) -> Bool
}

class LocalUserDefaultsWrapper: UserDefaultsWrapper {
    private let userDefaults = UserDefaults.standard

    // Issue #70: synchronize() は iOS 12 以降 deprecated かつ不要 (UserDefaults が自動で永続化する)

    func saveData(key: String, value: Int) {
        userDefaults.set(value, forKey: key)
    }

    func loadData(key: String) -> Int {
        userDefaults.integer(forKey: key)

        // default 0
    }

    func saveData(key: String, value: Bool) {
        userDefaults.set(value, forKey: key)
    }

    func loadData(key: String) -> Bool {
        userDefaults.bool(forKey: key)

        // default false
    }
}
```

- [ ] **Step 6: 生文字列キーと `synchronize()` が消えたことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
echo "--- 生文字列 hasLaunchedBefore ---"; grep -rn '"hasLaunchedBefore"' --include="*.swift" LeafTimer ; \
echo "--- synchronize ---"; grep -rn "synchronize()" --include="*.swift" LeafTimer
```

期待: **どちらも 0 件** (`LeafTimer/` = 本番コードのみ。テスト側の文字列リテラルは Step 1 で意図的に残しているので `LeafTimerTests/` は対象外)。

- [ ] **Step 7: テストが通ることを確認する**

Bash timeout を **600000** に設定する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tail -30
```

期待: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` なし。特に `DataPersistenceTests` の save/load ラウンドトリップが green であること (= `synchronize()` 削除に回帰なし) を出力で確認する。

- [ ] **Step 8: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/LeafTimer/Components/LocalUserDefaultWrapper.swift \
        app/LeafTimer/Components/UserDefaultItem.swift \
        app/LeafTimer/ViewModel/TimerViewModel.swift \
        app/LeafTimerTests/ && \
git commit -m "refactor(#70): UserDefaults 衛生 (synchronize 削除 + 初回起動キーの enum 化)

- LocalUserDefaultsWrapper の synchronize() 2 箇所を削除 (iOS 12+ で deprecated かつ不要)
- TimerViewModel の生文字列 \"hasLaunchedBefore\" を UserDefaultItem 経由に統一
- rawValue は既存ユーザーの設定を保つため \"hasLaunchedBefore\" のまま固定し、テストで固定化"
```

---

## Task 5: Issue #70-c — Info.plist / AppDelegate の残骸と force unwrap を掃除する

**Files:**
- Modify: `app/LeafTimer/Info.plist:270-273`
- Modify: `app/LeafTimer/App/AppDelegate.swift:11,12,23-33,60,68`
- Test: 新規テストなし (`AppDelegate` はテスト対象外。ビルド + Simulator 起動で検証)

**Interfaces:**
- Consumes: なし
- Produces: なし

**背景 (実地確認済み):**
- `Info.plist` の `UIRequiredDeviceCapabilities = [armv7]` は deployment target が iOS 17.0 (全端末 arm64) の今、意味の無い残骸。App Store 側で 32bit 端末向けと誤解される可能性もある。
- `AppDelegate.swift:11` の `oldBackgroundTaskID` はどこからも読み書きされない。`:12` の `timer` は `:68` で `invalidate()` されるだけで**一度も代入されない**ため常に nil の実質デッド。
- `AppDelegate.swift:60` の `(self?.backgroundTaskID)!` はリポジトリで唯一の force unwrap。expiration handler は `self` が解放済みでも呼ばれうるためクラッシュ経路になる。
- `AppDelegate.swift:27,31` で `LocalUserDefaultsWrapper()` を VM ごとに別インスタンス生成している。同じ `UserDefaults.standard` を見るため実害はないが DI の意図が薄い。

- [ ] **Step 1: `Info.plist` の armv7 を削除する**

`app/LeafTimer/Info.plist` から以下の 4 行を削除する:

```xml
	<key>UIRequiredDeviceCapabilities</key>
	<array>
		<string>armv7</string>
	</array>
```

削除後に plist が壊れていないことを検証する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
plutil -lint LeafTimer/Info.plist && \
grep -c "armv7" LeafTimer/Info.plist
```

期待: `LeafTimer/Info.plist: OK` が出て、`grep -c` が `0` を返す (`grep -c` は 0 件でも `0` を出力し exit 1 になるので、出力の数字で判定する)。

- [ ] **Step 2: `AppDelegate.swift` の未使用宣言・force unwrap・重複 wrapper を直す**

`app/LeafTimer/App/AppDelegate.swift` を以下の内容に置き換える:

```swift
import Firebase
import SwiftUI
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var backgroundTaskID = UIBackgroundTaskIdentifier(rawValue: 0)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        // GADMobileAds の start は UMP 同意 + ATT 完了後に AdsBootstrapper が行う (#57)

        window = UIWindow()

        // Issue #70: 同一の UserDefaults.standard を見るラッパーを VM ごとに
        // 別インスタンス生成していたため 1 つに集約する (振る舞いは不変)。
        let userDefaultWrapper = LocalUserDefaultsWrapper()

        let contentView = TimerView(
            timerViewModel: TimerViewModel(
                timerManager: DefaultTimerManager(),
                audioManager: DefaultAudioManager(),
                userDefaultWrapper: userDefaultWrapper,
                sessionStatsRepository: LocalSessionStatsRepository()
            ),
            settingViewModel: SettingViewModel(
                userDefaultWrapper: userDefaultWrapper
            )
        )

        let vc = UIHostingController(rootView: contentView)

        window?.rootViewController = vc
        window?.makeKeyAndVisible()

        // 同意フォーム/ATT ダイアログの提示は app active 後である必要があるため
        // 起動処理完了後の main queue で開始する
        DispatchQueue.main.async { [weak self] in
            AdsBootstrapper.shared.bootstrap(
                from: self?.window?.rootViewController,
                completion: nil
            )
        }

        // AVAudioSession の設定は DefaultAudioManager に一元化している (#55)。
        // ここで options 無しの setCategory を呼ぶと .mixWithOthers が上書きされ、
        // 他アプリの音楽がタイマー起動時に停止する。
        return true
    }

    // バックグラウンド遷移移行直前に呼ばれる
    func applicationWillResignActive(_ application: UIApplication) {
        // 新しいタスクを登録
        backgroundTaskID = application.beginBackgroundTask {
            [weak self] in
            // Issue #70: expiration handler は self 解放後にも呼ばれうるため
            // force unwrap を guard let に置き換える。
            guard let self else { return }
            application.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
    }

    // アプリがアクティブになる度に呼ばれる
    func applicationDidBecomeActive(_ application: UIApplication) {
        // タスクの解除
        application.endBackgroundTask(backgroundTaskID)
    }
}
```

変更点は 4 つ:
1. `var oldBackgroundTaskID` を削除 (参照 0 件)
2. `var timer: Timer?` と `applicationDidBecomeActive` の `timer?.invalidate()` を削除 (一度も代入されない実質デッド)
3. `(self?.backgroundTaskID)!` を `guard let self else { return }` + `self.backgroundTaskID` に置換
4. `LocalUserDefaultsWrapper()` の 2 回生成を 1 つの `let userDefaultWrapper` に集約

- [ ] **Step 3: 削除対象が本当に他から参照されていないことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
echo "--- oldBackgroundTaskID ---"; grep -rn "oldBackgroundTaskID" --include="*.swift" . | grep -v Pods ; \
echo "--- force unwrap ---"; grep -rn 'backgroundTaskID)!' --include="*.swift" . | grep -v Pods ; \
echo "--- AppDelegate.timer への外部参照 ---"; grep -rn "appDelegate\.timer\|delegate\.timer" --include="*.swift" . | grep -v Pods
```

期待: **3 つとも 0 件**。もし `LeafTimerTests/` 側から参照されていたら削除せず報告する。

- [ ] **Step 4: フルテストを実行する**

Bash timeout を **600000** に設定する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

期待: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` / `Error 6` なし。

- [ ] **Step 5: Simulator で起動してクラッシュしないことを確認する**

`Info.plist` と `AppDelegate` は単体テストで守られていないため、実起動で確認する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,id=$SIM" build 2>&1 | tail -3 && \
BUILT=$(xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,id=$SIM" -showBuildSettings 2>/dev/null \
  | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //') && \
xcrun simctl install "$SIM" "$BUILT/LeafTimer.app" && \
xcrun simctl spawn "$SIM" defaults write jp.ema.LeafTimer hasSeenOnboarding -bool true && \
xcrun simctl launch "$SIM" jp.ema.LeafTimer
```

数秒おいてからスクリーンショットを撮り、タイマー画面が正常表示されていることを Read で確認する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
xcrun simctl io "$SIM" screenshot /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/scratch-70-appdelegate.png
```

- [ ] **Step 6: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/LeafTimer/Info.plist app/LeafTimer/App/AppDelegate.swift && \
git commit -m "refactor(#70): Info.plist の armv7 残骸と AppDelegate の未使用宣言・force unwrap を掃除

- UIRequiredDeviceCapabilities=armv7 を削除 (deployment target iOS 17 は全端末 arm64)
- oldBackgroundTaskID / timer の未使用宣言を削除
- (self?.backgroundTaskID)! を guard let self に置換 (リポジトリ唯一の force unwrap)
- LocalUserDefaultsWrapper の VM ごと別インスタンス生成を 1 つに集約"
```

---

## Task 6: Issue #70-d — deprecated な StoreKit レビュー API を移行する

**Files:**
- Modify: `app/LeafTimer/Components/StoreKitReviewRequester.swift:2,16`
- Test: 既存の `app/LeafTimerTests/ReviewIntegrationSpec.swift` / `ReviewRequestPolicySpec.swift` が回帰ガード (protocol `ReviewRequesting` は不変のため signature 変更なし)

**Interfaces:**
- Consumes: なし
- Produces: なし (`ReviewRequesting` protocol の形は変えない)

**背景 (実地確認済み):**
`SKStoreReviewController.requestReview(in:)` は iOS 18 で deprecated。後継は `AppStore.requestReview(in:)` (iOS 16.0+)。**このアプリの deployment target は iOS 17.0** なので `#available` ガードは不要 (Task 開始前に `grep -o "IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;" LeafTimer.xcodeproj/project.pbxproj | sort -u` で `17.0` を再確認すること)。

現行 `SKStoreReviewController.requestReview(in:)` も `@MainActor` 隔離であり、既存コードがその文脈でコンパイルできている以上、`AppStore.requestReview(in:)` への差し替えでも隔離要件は変わらない。

- [ ] **Step 1: deployment target が 16.0 以上であることを再確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
grep -o "IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;" LeafTimer.xcodeproj/project.pbxproj | sort -u
```

期待: `IPHONEOS_DEPLOYMENT_TARGET = 17.0;` のみ。**16.0 未満が 1 つでも出たらこのタスクを中止し、`#available(iOS 16.0, *)` ガードを足す設計に切り替えてユーザーに報告する。**

- [ ] **Step 2: `StoreKitReviewRequester.swift` を書き換える**

`app/LeafTimer/Components/StoreKitReviewRequester.swift` を以下に変更する:

```swift
import Foundation
import StoreKit
import UIKit

protocol ReviewRequesting {
    func requestReview()
    func openAppStoreReviewPage()
}

final class StoreKitReviewRequester: ReviewRequesting {
    func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        // Issue #70: SKStoreReviewController.requestReview(in:) は iOS 18 で deprecated。
        // deployment target が iOS 17 のため #available ガードなしで移行できる。
        AppStore.requestReview(in: scene)
    }

    func openAppStoreReviewPage() {
        guard let appID = Bundle.main.object(forInfoDictionaryKey: "LeafTimerAppStoreID") as? String,
              !appID.isEmpty,
              let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") else {
            return
        }
        UIApplication.shared.open(url)
    }
}
```

`import StoreKit` は `AppStore` にも必要なので残す。

- [ ] **Step 3: ビルドして deprecation 警告が消えたことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" build 2>&1 \
  | grep -i "StoreKitReviewRequester\|deprecated\|BUILD SUCCEEDED\|BUILD FAILED" | head -20
```

期待: `** BUILD SUCCEEDED **` があり、`StoreKitReviewRequester.swift` を指す `deprecated` 警告が**無い**こと。

`AppStore.requestReview(in:)` が MainActor 隔離でコンパイルエラーになった場合は、`requestReview()` の中身を以下に変える:

```swift
        MainActor.assumeIsolated {
            AppStore.requestReview(in: scene)
        }
```

これは `requestReview()` が UI イベント由来で常に main thread から呼ばれる前提に依る。呼び出し元が main thread であることを `TimerViewModel.swift:297` の呼び出し経路で確認してから適用すること。

- [ ] **Step 4: フルテストを実行する**

Bash timeout を **600000** に設定する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

期待: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` なし。

- [ ] **Step 5: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/LeafTimer/Components/StoreKitReviewRequester.swift && \
git commit -m "refactor(#70): SKStoreReviewController を AppStore.requestReview に移行

- iOS 18 で deprecated の SKStoreReviewController.requestReview(in:) を置換
- deployment target が iOS 17.0 のため #available ガードは不要
- ReviewRequesting protocol は不変のため既存テスト・Mock に影響なし"
```

---

## Task 7: Issue #70-e — レビューで拾った可読性 cleanup (`leafLayer` の Optional / `CircleButton` の比率リテラル)

**Files:**
- Modify: `app/LeafTimer/View/TimerView.swift:173-198`
- Modify: `app/LeafTimer/View/Elements/CircleButton.swift:24-53`
- Create: `app/LeafTimerTests/CircleButtonRatioTests.swift`
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj` (新規テストファイル配線 + `make sort`)

**Interfaces:**
- Consumes: なし
- Produces: `CircleButton.innerRatios` — `static let innerRatios: (second: CGFloat, third: CGFloat, inner: CGFloat)`

**背景 (実地確認済み):**
Issue #70 の 2026-08-23 コメント項目 1 と 2。どちらも**振る舞い不変**の可読性改善。

1. `TimerView.leafLayer` の `let pattern: LeafPattern?` は 3 分岐すべてが非 nil を返すため実質デッド Optional。**`TimerViewModel+extensions.swift:157` の `func getLeafPattern() -> LeafPattern` が非 Optional であることは 2026-08-26 時点で確認済み** (Step 1 でもう一度 grep して裏を取る)。
2. `CircleButton` の `140/150` `120/150` `105/150` (105/150 は 2 箇所) はリテラル重複で、将来のデザイン変更で取りこぼしが出る。

- [ ] **Step 1: `getLeafPattern()` の戻り値が非 Optional であることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
grep -rn "func getLeafPattern" --include="*.swift" LeafTimer
```

期待: `-> LeafPattern` (末尾に `?` が**無い**こと)。`-> LeafPattern?` だった場合は Optional は実質デッドではないので、**このステップで止めて Step 4 の `leafLayer` 変更をスキップし、その旨を報告する。**

- [ ] **Step 2: `CircleButton` の比率を固定する失敗テストを書く**

`app/LeafTimerTests/CircleButtonRatioTests.swift` を新規作成する:

```swift
import XCTest
@testable import LeafTimer

/// Issue #70: CircleButton の内側円比率をリテラル重複から static 定数に集約した際、
/// 見た目が変わっていないことを固定するテスト。
final class CircleButtonRatioTests: XCTestCase {

    func testInnerRatiosMatchOriginalLiterals() {
        XCTAssertEqual(CircleButton.innerRatios.second, 140.0 / 150.0, accuracy: 0.0001)
        XCTAssertEqual(CircleButton.innerRatios.third, 120.0 / 150.0, accuracy: 0.0001)
        XCTAssertEqual(CircleButton.innerRatios.inner, 105.0 / 150.0, accuracy: 0.0001)
    }

    func testResolvedDiameterIsCappedAtMaxDiameter() {
        XCTAssertEqual(CircleButton.resolvedDiameter(scaled: 150), 150, accuracy: 0.0001)
        XCTAssertEqual(CircleButton.resolvedDiameter(scaled: 300), CircleButton.maxDiameter, accuracy: 0.0001)
    }
}
```

- [ ] **Step 3: 新規テストファイルを test target に配線し、失敗することを確認する**

`app/LeafTimer.xcodeproj/project.pbxproj` に `CircleButtonRatioTests.swift` を追加する。手順は Task 3 Step 3 と同じ 4 箇所だが、**グループは `LeafTimerTests`、build phase は test target の `PBXSourcesBuildPhase`** である点が異なる。既存テストファイルの登録を参照する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
grep -n "PhaseReconcilerTests.swift" LeafTimer.xcodeproj/project.pbxproj
```

配線後:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make sort && make precheck 2>&1 | tail -10
```

そのあと Bash timeout **600000** でテスト実行:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tail -30
```

期待: **コンパイルエラー** `type 'CircleButton' has no member 'innerRatios'` で `** TEST FAILED **`。失敗理由が予測どおりであることを確認してから次へ。

- [ ] **Step 4: `CircleButton` の比率を `innerRatios` に集約する**

`app/LeafTimer/View/Elements/CircleButton.swift` の `body` と静的定義を以下に変更する (ファイル冒頭のコメントヘッダと `import SwiftUI`、`CircleButton_Previews` はそのまま):

```swift
struct CircleButton: View {
    @ObservedObject var viewModel: TimerViewModel

    /// Issue #64: AX5 で文言が「S…」に省略される対策。文字だけでなく円ごと
    /// Dynamic Type に追従させる (#58 のタイマー数字と同じ ScaledMetric + 上限方式)。
    @ScaledMetric(relativeTo: .title) private var scaledDiameter: CGFloat = 150

    static let maxDiameter: CGFloat = 210

    /// Issue #70: 入れ子の円の直径比。元は 140/150・120/150・105/150 のリテラル
    /// 重複で、105/150 は 2 箇所に散っていた。デザイン変更時の取りこぼしを防ぐため集約。
    static let innerRatios: (second: CGFloat, third: CGFloat, inner: CGFloat) = (
        second: 140.0 / 150.0,
        third: 120.0 / 150.0,
        inner: 105.0 / 150.0
    )

    /// 最内円のテキスト幅は最内円直径の 95%。
    private static let innerTextWidthRatio: CGFloat = 0.95

    static func resolvedDiameter(scaled: CGFloat) -> CGFloat {
        min(scaled, maxDiameter)
    }

    var body: some View {
        let outer = Self.resolvedDiameter(scaled: scaledDiameter)
        let second = outer * Self.innerRatios.second
        let third = outer * Self.innerRatios.third
        let inner = outer * Self.innerRatios.inner
        Circle()
            .fill(viewModel.getColor1())
            .frame(width: outer, height: outer, alignment: .center)
            .overlay(
                Circle()
                    .fill(viewModel.getColor2())
                    .frame(width: second, height: second, alignment: .center)
                    .overlay(
                        Circle()
                            .fill(viewModel.getColor3())
                            .frame(width: third, height: third, alignment: .center)
                            .overlay(
                                Circle()
                                    .fill(viewModel.getColor4())
                                    .frame(width: inner, height: inner, alignment: .center)
                                    .overlay(
                                        Text(viewModel.getButtonState())
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                            .frame(width: inner * Self.innerTextWidthRatio)
                                    )
                            )
                    )
            ).shadow(color: .gray, radius: 1, x: 0, y: 1)
    }
}
```

- [ ] **Step 5: テストが通ることを確認する**

Bash timeout を **600000** に設定する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tail -30
```

期待: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` なし。

- [ ] **Step 6: `leafLayer` の実質デッド Optional を解消する**

Step 1 で `getLeafPattern()` が非 Optional だと確認できた場合のみ実施する。`app/LeafTimer/View/TimerView.swift:173-198` を置換する。変更前:

```swift
    private func leafLayer(metrics: TimerLayoutMetrics) -> some View {
        let pattern: LeafPattern? = {
            if timerViewModel.breakState { return .big }
#if DEBUG
            if let forced = DebugLeafPattern.requested { return forced }
#endif
            return timerViewModel.getLeafPattern()
        }()

        if let pattern {
            let gifName = switch pattern {
            case .small: "leaf1"
            case .mid: "leaf2"
            case .big: "leaf3"
            }
            GIFView(gifName: gifName)
                .frame(
                    width: metrics.leafSize(for: pattern),
                    height: metrics.leafSize(for: pattern),
                    alignment: .center
                )
                .padding(.leading, metrics.leafLeadingPadding(for: pattern))
                .padding(.trailing, metrics.leafTrailingPadding(for: pattern))
                .padding(.bottom, metrics.leafBottomPadding(for: pattern))
        }
    }
```

変更後:

```swift
    private func leafLayer(metrics: TimerLayoutMetrics) -> some View {
        // Issue #70: 3 分岐すべてが非 nil を返すため Optional は実質デッドだった。
        // 誤読を招くので非 Optional に落とす (振る舞い不変)。
        let pattern: LeafPattern = {
            if timerViewModel.breakState { return .big }
#if DEBUG
            if let forced = DebugLeafPattern.requested { return forced }
#endif
            return timerViewModel.getLeafPattern()
        }()

        let gifName = switch pattern {
        case .small: "leaf1"
        case .mid: "leaf2"
        case .big: "leaf3"
        }
        return GIFView(gifName: gifName)
            .frame(
                width: metrics.leafSize(for: pattern),
                height: metrics.leafSize(for: pattern),
                alignment: .center
            )
            .padding(.leading, metrics.leafLeadingPadding(for: pattern))
            .padding(.trailing, metrics.leafTrailingPadding(for: pattern))
            .padding(.bottom, metrics.leafBottomPadding(for: pattern))
    }
```

`if let` を外したことで暗黙 return が使えなくなるため、`return GIFView(...)` と明示している点に注意。

- [ ] **Step 7: フルテストを実行する**

Bash timeout を **600000** に設定する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

期待: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` / `Error 6` なし。

- [ ] **Step 8: Simulator で葉のパターン 3 種とボタンの見た目が変わっていないことを確認する**

CLAUDE.md ルール 32 の起動引数 `-LeafPattern=small|mid|big` で 3 パターンを強制できる。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,id=$SIM" build 2>&1 | tail -3 && \
BUILT=$(xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer \
  -destination "platform=iOS Simulator,id=$SIM" -showBuildSettings 2>/dev/null \
  | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //') && \
xcrun simctl install "$SIM" "$BUILT/LeafTimer.app" && \
xcrun simctl spawn "$SIM" defaults write jp.ema.LeafTimer hasSeenOnboarding -bool true
```

3 パターンを **1 つずつ別々の Bash 呼び出しで** 起動して撮る。ループ内で連続撮影すると遷移アニメ中の旧フレームを掴むため (ルール 32)、必ず 1 パターン = 1 呼び出しにする。`<p>` を `small` / `mid` / `big` に置き換えて 3 回実行する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
xcrun simctl terminate "$SIM" jp.ema.LeafTimer 2>/dev/null; \
xcrun simctl launch "$SIM" jp.ema.LeafTimer "-LeafPattern=<p>"
```

各起動の数秒後 (別の Bash 呼び出し) に撮影する:

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && \
SIM=$(xcrun simctl list devices available | grep "iPhone 17 (" | head -1 | grep -oE '[0-9A-F-]{36}') && \
xcrun simctl io "$SIM" screenshot /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/scratch-70-leaf-<p>.png
```

3 枚を Read して確認する:
1. 葉の GIF が 3 パターンとも表示され、サイズ・位置が pattern ごとに変わっている
2. 中央の開始ボタンの入れ子円 4 層の見た目が変わっていない

- [ ] **Step 9: commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git add app/LeafTimer/View/TimerView.swift \
        app/LeafTimer/View/Elements/CircleButton.swift \
        app/LeafTimerTests/CircleButtonRatioTests.swift \
        app/LeafTimer.xcodeproj/project.pbxproj && \
git commit -m "refactor(#70): leafLayer の実質デッド Optional 解消と CircleButton 比率の集約

- leafLayer: 3 分岐すべて非 nil のため LeafPattern? を LeafPattern に落とす
- CircleButton: 140/150・120/150・105/150 (2 箇所) を innerRatios に集約
- CircleButtonRatioTests で比率と maxDiameter 上限を固定化
- pbxproj への配線と make sort を同 commit に含める"
```

---

## Task 8: Issue #70 の PR 作成と merge

**Files:** なし (git 操作のみ)

**Interfaces:**
- Consumes: Task 3〜7 の 5 commit
- Produces: なし

- [ ] **Step 1: 全 commit が揃っていることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git log --oneline master..feature/70-code-hygiene-cleanup && \
git status --short
```

期待: 5 つの commit が並び、`git status --short` は空 (未 commit の差分なし)。

- [ ] **Step 2: 最終のフルテストを実行する**

Bash timeout を **600000** に設定する。

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

期待: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` / `Error 6` / `No rule to make target` なし。

- [ ] **Step 3: 既存 PR が無いことを確認して push する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git fetch && gh pr list --state all --head feature/70-code-hygiene-cleanup
```

既存 PR が無いことを確認してから:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
git push -u origin feature/70-code-hygiene-cleanup
```

- [ ] **Step 4: PR を作成する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
gh pr create --base master --title "refactor: #70 コード衛生 minor cleanup まとめ" --body "$(cat <<'EOF'
## 概要
Issue #70 の本文 7 項目 + 2026-08-23 コメントの 3 項目を、**振る舞い不変**のまま回収しました。5 commit に分けています。

## 対応内容

| # | 項目 | 対応 | commit |
| --- | --- | --- | --- |
| 1 | 本番コードのデバッグ `print()` 多数 | `os.Logger` (`AppLogger.swift` 新設) に 15 箇所置換 | 1 |
| 2 | `LocalUserDefaultWrapper` の `synchronize()` | 2 箇所削除 (iOS 12+ で deprecated かつ不要) | 2 |
| 3 | `Info.plist` の `UIRequiredDeviceCapabilities = armv7` | 削除 (deployment target iOS 17 は全端末 arm64) | 3 |
| 4 | `TimerViewModel` の生文字列 `"hasLaunchedBefore"` | `UserDefaultItem.hasLaunchedBefore` に統一 | 2 |
| 5 | `AppDelegate` の未使用宣言 + 唯一の force unwrap | `oldBackgroundTaskID` / `timer` 削除、`guard let self` に置換 | 3 |
| 6 | `SKStoreReviewController.requestReview(in:)` (iOS 18 deprecated) | `AppStore.requestReview(in:)` に移行 | 4 |
| 7 | `AppDelegate` の wrapper 別インスタンス生成 | 1 つに集約 | 3 |
| C1 | `TimerView.leafLayer` の実質デッド Optional | `LeafPattern?` → `LeafPattern` | 5 |
| C2 | `CircleButton` の内側円比率リテラル重複 | `innerRatios` に集約 + テストで固定 | 5 |

## 既に解消済みだった項目
- **`AdsView.swift:9` の広告ユニット ID を `print()`** — 現行 `AdsView.swift` に `print()` は 1 件も存在しません (`AdsBootstrapper` 経由の実装に置き換わり、ユニット ID は `KeyManager().getAdUnitID()` から banner に直接渡されるのみ)。コード変更不要でした。

## 本 PR のスコープ外 (defer)
- **C3: `ModernTimerViewSpec` の index ベース ViewInspector パス** — issue コメント自身が「xit 群整理のタイミングでまとめて」としており、対象 2 件は Issue #16 以来すでに `xit` 無効化済みです。xit 群の整理と合わせて別途対応します。

## 安全性の確認
- **UserDefaults の永続化キーは一切変えていません。** `UserDefaultItem.hasLaunchedBefore` の rawValue は既存の文字列 `"hasLaunchedBefore"` と同一で、`testHasLaunchedBeforeRawValueIsUnchanged` で固定しています (別名にすると全既存ユーザーのサウンド設定が初回起動扱いで上書きされるため)
- `ReviewRequesting` protocol は不変のため既存テスト・Mock に影響なし
- `os.Logger` の補間値には `privacy: .public` を明示 (既定の private だと実機の log stream で `<private>` にマスクされ調査不能になるため)。出力されるのは OS のエラー記述とアセット名のみで個人情報を含みません

## 検証
- `make tests` green (`** TEST SUCCEEDED **`)
- `make precheck` で新規 2 ファイル (`AppLogger.swift` / `CircleButtonRatioTests.swift`) の target 配線を確認、`make sort` を各追加 commit に同梱
- Simulator (iPhone 17) で起動確認 + 葉パターン 3 種 (`-LeafPattern=small|mid|big`) のスクリーンショット比較で見た目不変を確認
- `plutil -lint Info.plist` OK

## 備考
実装計画: `docs/superpowers/plans/2026-08-26-minor-cleanup-bundle-66-85-70.md` (#66/#85/#70 の 3 本立て。本 PR はその 3 本目)

Closes #70

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01FhYNKDgBJ6MqpYG6fYJYv8
EOF
)"
```

- [ ] **Step 5: CI を待って merge する**

Task 1 Step 11 と同じ手順:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh pr checks <PR番号>
```

出力の URL 末尾から run ID を取り、run ごとにフォアグラウンドで watch:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && gh run watch <run-id> --interval 30
```

全 run 完了後、同一チェーンで再検証して merge:

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
gh pr checks <PR番号> && gh pr merge <PR番号> --merge
```

- [ ] **Step 6: 3 issue がすべて close されたことを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && \
gh issue view 66 --json state,closedAt && \
gh issue view 85 --json state,closedAt && \
gh issue view 70 --json state,closedAt
```

期待: 3 件とも `"state": "CLOSED"`。`Closes #N` で自動 close されていなければ手動で close し、その際に PR へのリンクをコメントする。

- [ ] **Step 7: defer した項目を issue に記録する (silent drop 禁止)**

`ModernTimerViewSpec` の index ベースパス問題は #70 の close で消えてしまうため、行き先を確保する。`AskUserQuestion` でユーザーに聞く:

- 質問: 「#70 から defer した『ModernTimerViewSpec の index ベース ViewInspector パスを `find(ViewType.Button.self)` 形式へ寄せる』の行き先は？」
- 選択肢 A: 「新規 issue を起票する (Recommended)」 — `gh issue create` で tech-debt ラベル付きで起票し、#16 と #70 を参照
- 選択肢 B: 「既存の #76 (形骸化した UI テストターゲット整理) にコメントで追記する」 — xit 群整理と同じ文脈のため
- 選択肢 C: 「記録しない」

選ばれた行き先を実行してからタスク完了とする。

---

## Self-Review

**1. Spec coverage:**

| Issue / 項目 | 対応タスク |
| --- | --- |
| #66 ツールバーアイコン SF Symbols 統一 | Task 1 |
| #85 claude.yml 要否判断 | Task 2 (bot 調査で決着済み → README 記載) |
| #85 Pods deny パターン検証 | Task 2 (bot 検証で正常確認済み → コード変更なしと明記) |
| #70-1 `print()` 多数 | Task 3 |
| #70-1 `AdsView.swift:9` の広告 ID 出力 | Task 3 背景 + Task 8 PR 本文 (既に解消済みとして報告) |
| #70-2 `synchronize()` | Task 4 |
| #70-3 `armv7` | Task 5 |
| #70-4 `"hasLaunchedBefore"` 生文字列 | Task 4 |
| #70-5 `AppDelegate` 未使用宣言 + force unwrap | Task 5 |
| #70-6 `SKStoreReviewController` deprecated | Task 6 |
| #70-7 wrapper の別インスタンス生成 | Task 5 |
| #70-C1 `leafLayer` の Optional | Task 7 |
| #70-C2 `CircleButton` の比率リテラル | Task 7 |
| #70-C3 `ModernTimerViewSpec` index パス | **意図的な defer** — Task 8 Step 7 で行き先を決定 (silent drop 回避) |

ギャップなし。

**2. Placeholder scan:** 「TBD」「後で」「適切にエラー処理」「Task N と同様」の類は含まれていない。全コードブロックが実際の変更後コードを含む。条件付きの分岐 (Task 6 Step 3 の MainActor、Task 7 Step 1 の Optional 判定) は、条件と対処の両方を明示している。

**3. Type consistency:**
- `AppLogger.audio` / `.notification` / `.gif` — Task 3 Step 2 で定義、Step 6・7 で同名使用。一致。
- `UserDefaultItem.hasLaunchedBefore` — Task 4 Step 3 で定義、Step 1 のテストと Step 4 の実装で同名使用。一致。
- `CircleButton.innerRatios.second/.third/.inner` — Task 7 Step 4 で定義、Step 2 のテストで同名使用。一致。
- `CircleButton.resolvedDiameter(scaled:)` / `.maxDiameter` — 既存 API を変更していないため Step 2 のテストは既存 signature に合う。
- ブランチ名 `feature/66-sf-symbols-toolbar` / `feature/85-readme-claude-workflows` / `feature/70-code-hygiene-cleanup` — 各タスクの作成・push・PR 作成で表記一致。
