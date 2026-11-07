# LeafTimer v1.6.2 リリースノート

- 対象: MARKETING_VERSION 1.6.2 (#198 で 1.6.1 から上げた)。ビルドは build 51 (PR #198 の merge で Xcode Cloud が作成、2026-11-07 に TestFlight で「提出準備完了」を確認)
- build 51 は 2026-11-07 に却下された (Guideline 2.1(a))。iPadOS 27.2 で、UIScene ライフサイクル未対応による起動クラッシュが起きたため (#201)。再提出には #201 の merge 後に Xcode Cloud が作るビルドを使う。番号は TestFlight で確かめてから書く
- 入力元: v1.6.1 タグ以降の merged PR はバージョン上げ (#198) だけ。ストアの文言の変更は #197 (`docs/app-store-metadata.md`)
- `asc-submission-prep` skill が「What's New」節を ASC の「このバージョンの最新情報」に使う
- 名前・サブタイトル・キーワード・説明文・プロモーション用テキストは ja / en とも `docs/app-store-metadata.md` の値に変える。名前とサブタイトルは 1.6.2 の提出物に含まれることを ASC で確かめてから提出する

## What's New

### ja

・ストアの説明を新しくしました

### en

- Updated the App Store description

## 物差し (#197)

- 基準値 (ASC アナリティクス、2026-10-07〜11-05 の 30 日): インプレッション 1,790 / プロダクトページ閲覧 112 / 初回ダウンロード 10 / コンバージョン率 0.9%
- 1.6.2 配信の 30 日後に同じ画面を読み、インプレッションと初回ダウンロードを比べる。あわせて「ポモドーロ」「集中 タイマー」「勉強 タイマー」「作業 タイマー」(jp)、「pomodoro」「focus timer」(us) で iTunes Search API の 50 位以内に入ったかを取り直す
