# Issue #75: PR 自動テスト CI ゲート — 設計

- 日付: 2026-08-03
- 対象 Issue: #75 (PR で自動テストが回る CI ゲートを構築する)
- ステータス: 承認済み (方式・スコープ・設計とも AskUserQuestion で確認済み)

## 背景 / 問題

`make tests` の資産 (precheck / sort / SwiftLint / xcodebuild unit-tests) は整備されているのに、
PR・マージのどちらでも自動実行される仕組みが無い。品質担保がローカル実行への依存に留まっている。

- `.github/workflows/` は claude bot 系 2 本のみ (テスト実行 step ゼロ)
- Xcode Cloud は post-merge の Archive のみ (Test アクション無し)

## 決定事項

### 方式: GitHub Actions (macOS runner)

- 本リポジトリは **public** のため macOS runner を含め **無料・分数無制限**。
  Issue 記載の「コスト確認」の懸念は解消済み。
- 設定 (YAML) が repo 内に置かれ、レビュー・再現・修正が容易。
- Xcode Cloud は現状の post-merge Archive のまま**触らない**。

### スコープ

含む:

1. PR トリガーで `make tests` を実行する workflow
2. sort ゲート (`make sort` 起因の pbxproj 差分検知)
3. green 実績確認後の**必須チェック化** (branch protection)
4. RED 検証 (わざと壊して fail することの実証)

含まない (明示的に見送り):

- Code Coverage 計測 (`-enableCodeCoverage YES`) — Issue #75 のチェックボックスだが別 PR に後送
- `make tests` チェーン外の ruby チェック (gitignore-doctor 等)
- master push トリガー (PR のみ)
- Xcode Cloud 側への Test workflow 追加

## 設計

### アプローチ: 単一 job で `make tests` (案A)

ローカルと CI が**完全に同じコマンド**を実行する single source of truth を優先する。
lint 先行の分割 job (案B) は fail-fast こそ速いが、YAML 複雑化と `make tests` との乖離
(Linux 版 SwiftLint / gem 環境差) のコストが、無料分数の今は見合わないため不採用。

### Workflow: `.github/workflows/pr-tests.yml`

- トリガー: `pull_request` (base: master)
- `concurrency`: 同一 PR の古い実行を cancel-in-progress
- job timeout: 30 分 (xcodebuild ハング対策)

Steps:

1. checkout
2. Xcode 選定: `iPhone 17` simulator (Makefile の `SIMULATOR` 既定値) が必要なため
   **Xcode 26 系**を `xcode-select`。runner image (macos-26 想定) 上の実在パスは
   実装時に `ls /Applications | grep Xcode` で実測して確定する (推測でバージョンを書かない)。
3. CocoaPods キャッシュ: `Pods/` を `Podfile.lock` ハッシュキーで restore/save
4. ツール存在確認: SwiftLint が image に無ければ `brew install swiftlint`
   (CLAUDE.md「マネージド runner はツール preinstall を保証しない」ルール準拠)
5. `cd app && pod install`
6. `cd app && make tests` — exit code を直接判定 (パイプフィルタ禁止、CLAUDE.md 準拠)
7. sort ゲート: `git diff --exit-code -- app/LeafTimer.xcodeproj/project.pbxproj`
   `make tests` 内の `make sort` が pbxproj を書き換えた = PR が sort 忘れ → fail。
   既知事故 (Issue #8 の sort 漏れ) の CI 検知。

### 必須チェック化

workflow が実 PR で green になった実績を 1 回作ってから、`gh api` で master の
branch protection に required status check として job 名を登録する。
(green 実績前に登録すると、名前ミスマッチ時に全 PR がマージ不能になるため順序厳守)

### エラーハンドリング / 検証戦略 (CI の CI)

- checker の本体は FAIL(RED) パス。workflow 追加 PR 自体で:
  1. green 実績を確認
  2. わざと SwiftLint 違反 (または sort 崩し) を入れた commit で **RED になることを実証**
  3. revert して green に戻してからマージ
- xcodebuild の成否は `make` の exit code に委ね、出力の grep 判定はしない。

## 成功基準

- PR を出すと自動で `make tests` が走り、結果が PR の checks に表示される
- 壊れた変更 (lint 違反 / テスト失敗 / sort 忘れ) の PR が RED になる
- CI green が master へのマージ条件になっている
