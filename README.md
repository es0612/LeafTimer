# LeafTimer

簡易機能のタイマーアプリ


## Description

下記の機能を実装する
- 作業、休憩時間のタイマー機能
- 各種設定
- モード変更


## Requirement

chack cocoaPod file

## GitHub Actions

| Workflow | 起動条件 | 用途 |
| --- | --- | --- |
| `.github/workflows/pr-tests.yml` | PR 作成・更新時 | ユニットテストを実行する CI |
| `.github/workflows/claude-code-review.yml` | PR 作成・更新時 | Claude による自動コードレビュー (常時稼働) |
| `.github/workflows/claude.yml` | Issue / PR コメントで `@claude` とメンションした時 | Claude を対話的に呼び出して調査・修正させる。メンションが無い限り skip されるため、run 履歴が skipped 続きでも異常ではない |

配布ビルド (TestFlight / App Store) は GitHub Actions ではなく **Xcode Cloud** が担当する。

## Licence

Copyright 2025 by Author


## Author

AsaPapaLab.
