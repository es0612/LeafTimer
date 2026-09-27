# LeafTimer v1.5 リリースノート

- 対象: MARKETING_VERSION 1.5 (2026-09-28 配信開始、build 37)
- 入力元: PR #35 (2026-05-26) 以降の merged PR のうちユーザーに見える変更
- `asc-submission-prep` skill が「What's New」節を ASC の「このバージョンの最新情報」に使う

## What's New

### ja

・はじめての方向けのガイド画面を追加しました
・履歴画面で、連続日数・最長記録・過去 7 日の実績を確認できるようになりました
・アプリを閉じていてもタイマーが進み、作業と休憩の終わりを通知でお知らせします
・開始・停止ボタンに触覚フィードバックを追加しました
・VoiceOver と文字サイズの変更に対応しました
・「視差効果を減らす」がオンの時は、葉のアニメーションを止めるようにしました
・iPhone SE と iPad の画面レイアウトを改善しました
・タイマー開始時に、他のアプリで再生中の音楽が止まる問題を修正しました
・履歴の表示が 0 に戻ることがある問題を修正しました

### en

- New welcome guide for first-time users
- History screen: see your current streak, longest streak, and the last 7 days
- The timer keeps running in the background and notifies you when a work or break session ends
- Haptic feedback on the Start and Stop buttons
- VoiceOver and Dynamic Type support
- The leaf animation pauses when Reduce Motion is on
- Improved layouts on iPhone SE and iPad
- Fixed an issue where music from other apps stopped when the timer started
- Fixed an issue where the history sometimes reset to 0

## 振り返り (2026-09-28)

期間: 2026-05-26 (#35 で MARKETING_VERSION を 1.5 に上げた日) 〜 2026-09-28 (App Store で配信開始)。この間に merge した PR は #34〜#167 の 64 件。

### 事実

- 約 124 日・64 PR で 1 リリース。内訳は、振り返りを CLAUDE.md に追記する PR が 19 件 (30%)、ユーザーに見える機能追加 12 件、バグ修正 10 件、残りは CI・テスト基盤・checker
- CLAUDE.md の大きさ: 34.3KB → #111 で 11.5KB に圧縮 (2026-08-15) → 29.8KB (2026-09-27)。6 週間で圧縮前の 87% まで戻った
- 同じ話題の修正が 3 回ずつ続いた: CocoaPods の版固定 (#144 → #146 → #150)、checker の堅牢化 (#156 → #158 → #162)
- 申請は fastlane 経路 (#52) をやめ、Chrome 経路 (#165、`asc-submission-prep` skill) で通した。2026-09-27 に提出し、2026-09-28 04:09 JST に配信開始
- 配信後、ja の iPhone スクショが JP の Web ストアで v1.2 の旧画像のまま表示されていた。差し替えたのは 6.9" 枠だけで、旧 6.5" 枠の画像が残っていたため (#169)

### 解釈

- PR ごとの振り返りループは回っている。一方で、学びの受け皿が「CLAUDE.md に 1 行足す」しかないため、圧縮しても太り直す
- 1 リリースが大きすぎた。ストアの枠の棚卸しのように、リリースの時にしか通らない手順が 4 か月ぶりだったため、抜けに気づいたのが配信後になった

### 次サイクルへのアクション

| 学び | 行き先 | 状態 |
| --- | --- | --- |
| CLAUDE.md が再び太った | #171 (サイズ上限を make ターゲットで守る) | idea |
| 旧サイズの枠を棚卸ししていなかった / 配信後のストア表示を確かめる手段が無かった | `asc-submission-prep` skill (4b-6 と Common Mistakes に追加) | done |
| ja の旧スクショが表示されている | #169 (priority:high)。配信中バージョンのスクショ枠は読み取り専用なので、次のバージョンを作った時に旧 6.5" / 5.5" 枠を削除する | idea |
| `v1.5` の git tag が無い | build 37 (2026-09-27 13:32 JST 作成) の commit に tag を打つ。作成時刻から #167 の merge commit `cdaa1af` と推定 | done |
| リリースが大きすぎる | 物差しとして記録: バージョンを上げてから配信までの日数と PR 数 (今回 124 日・64 PR)。次の振り返りで比べる | done |
