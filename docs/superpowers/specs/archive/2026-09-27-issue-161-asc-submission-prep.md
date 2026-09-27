# #161 ASC 申請準備の自動化 (Chrome 経路) — spec

- Issue: #161
- 日付: 2026-09-27
- ステータス: validating (spec レビュー待ち)

## 1. 価値

Xcode Cloud がビルドを ASC に上げた後の「申請準備」を Claude が Chrome で提出ボタンの直前まで進め、人の作業を **(1) 差分表への一括 OK (2) What's New の手直し (3) 「審査へ提出」** の 3 つに減らす。あわせて、ストア用スクショを次回以降も再生成できる仕組みにする。

## 2. 前提 (2026-09-27 の実測)

| 事実 | 根拠 |
|---|---|
| ASC の LeafTimer は app ID `1520649806`。公開中は **1.4 (build 24)** | Chrome で配信タブを `get_page_text` |
| ASC に **1.5 のバージョンはまだ無い** | 同上 (「1.4 配信準備完了」のみ) |
| TestFlight に **1.5 build 30〜34** (最新 34、9/18) がある。Xcode Cloud がビルド番号を自動採番する (pbxproj は 25) | TestFlight を `get_page_text` |
| repo は `MARKETING_VERSION = 1.5` | `app/LeafTimer.xcodeproj/project.pbxproj:911,936` |
| fastlane (brew 2.238.0) は Apple ID ログインで `Service key is empty` → fastlane#30199、2.240.0 で修正済み | fastlane 実行ログ + GitHub API |
| fastlane 2.240.1 でも `.env.default` の App 用パスワードでは `Unauthorized Access`。安定させるには ASC API Key が要る | scratchpad で実行 |
| → **fastlane はやめて Chrome に一本化する** (ユーザー判断 2026-09-27) | — |
| グローバル skill `~/.claude/skills/asc-submission-prep/SKILL.md` (2026-09-27 10:27 作成) が Chrome 経路の読取→差分→一括 OK→書き込み→ビルド紐付け→停止レポートを持つ | ファイル本文 |
| 同 skill は「対象バージョンが ASC に既にある」前提で、**新バージョンの作成手順が無い**。スクショ差し替えは「未実走」 | 同上 |
| Apple のスクショ仕様: 6.9" は 1320×2868 等 (6.5" は「6.9" が無い場合に必須」)、iPad 13" は 2064×2752 / 2048×2732 (「iPad で動くなら必須」) | developer.apple.com screenshot-specifications を curl |
| 旧ストア掲載スクショ (`docs/ver1_2/screen/Slice*.png`) は緑グラデ背景 + 白抜きコピー + 端末画面の**デザイン合成済み画像**。iPhone 4 枚 (起動 / 待機 / 実行中の大きな木 / 設定) + iPad 4 枚 | 画像を目視 |
| Simulator: `iPhone 17 Pro Max` は同名 5 台 (1 台は他セッションで Booted)、`iPad Pro 13-inch (M5)` は 2 台 | `xcrun simctl list devices available` |
| 合成に使える画像ツール: PIL / ImageMagick なし、`swift` あり | `which` |

## 3. スコープ

### やること

- **A. 入力元**: `docs/RELEASE_v1.5.md` に What's New (ja / en) を置く。
- **B. スクショ生成**: Simulator 撮影 + デザイン合成を repo 内スクリプトと make ターゲットにする。
- **C. ASC 投入**: `asc-submission-prep` skill で v1.5 を提出直前まで進める (実走)。
- **D. skill 還元**: 実走で確定した不足分をグローバル skill に追記する。

### やらないこと

- 説明文・キーワード・サブタイトル・プロモーション文の変更 (skill の `skip` 扱い。live 値を保つ)
- 既存 6.5" / iPad スクショの削除 (削除は不可逆。6.9" / 13" を追加すれば ASC はそちらを優先する)
- fastlane `upload_metadata` lane と `fastlane/metadata/` の片付け → 別 issue を起票する
- 「審査用に追加」「審査へ提出」のクリック (人が押す)
- 輸出コンプライアンス等の法的質問への回答 (出たら停止して人に渡す)

## 4. 設計

### A. `docs/RELEASE_v1.5.md`

- skill が既定で読むパス (`docs/RELEASE_v<ver>.md` の What's New 節) に合わせる。
- 下書きの入力: 前回リリース PR #35 (2026-05-26) 以降の merged PR のうちユーザーに見える変更 (feat / fix。docs / chore / test / ci / build / refactor は除く)。
- 構成: `## What's New` 配下に `### ja` / `### en`。**en は絵文字禁止**、ja も絵文字は使わない (skill の実績: ja でも U+1FAE7 が拒否された)。ASC の上限 4,000 字以内。
- 人の判断点: 下書き commit 後、ASC 書き込み前にユーザーが手直しする。

### B. スクショ生成

```
make store-screenshots   (= capture → compose → check)
  capture : app/bin/store-screenshots-capture.sh
  compose : app/bin/store-screenshot-compose.swift  (CoreGraphics / CoreText、依存追加なし)
  check   : 出力寸法と枚数の検証 (sips)
入力      : app/store-screenshots/copy.json   (画面 ID × ロケールのコピー)
出力      : app/build/store-screenshots/<locale>/<device>/NN-<screen>.png  (git 管理外)
```

**撮影 (capture)**

- 専用 Simulator を `xcrun simctl create` で作り、UDID で扱う (同名機種の曖昧マッチと他セッションの Booted 機を避ける — ルール 30)。機種: `iPhone 17 Pro Max` (1320×2868 を期待)、`iPad Pro 13-inch (M5)` (2064×2752 を期待)。実寸は plan で実測する。
- 状態: `xcrun simctl status_bar override` で時刻 9:41・電池満タン・電波最大に固定。`hasSeenOnboarding=true`、ATT は `applesimutils` で事前付与 (ルール 32)。ロケールは `-AppleLanguages (ja|en)`。
- 画面 (5 枚): ①待機中タイマー ②実行中・大きな木 ③履歴 (streak / 過去 7 日) ④設定 ⑤オンボーディング (v1.5 の新機能)。既存の `-InitialScreen=` / `-LeafPattern=` を使う。
- 既存フックで足りない状態は DEBUG 限定の起動引数を足す (候補: 実行中状態、履歴のサンプルデータ、広告非表示)。**要否は plan 作成時に実機スクショで確定する** (実測前に足さない)。
- 起動画面 (splash) は採用しない: plan 作成時の実測で、起動 4 秒後に撮れたのは 1 回だけで再現しなかった (LaunchScreen の表示時間に依存)。旧ストアの 1 枚目 (起動画面) のコピー「集中習慣を育てよう」はオンボーディング画面に付け替える。

**合成 (compose)**

- 出力は Apple 仕様どおりの寸法ちょうど (iPhone 1320×2868、iPad 2064×2752)。
- レイアウト: 旧デザインに寄せる。上部に緑→水色の縦グラデーション背景と白抜き 2 行コピー (ja: Hiragino Sans W6、en: SF Pro Bold)。下部に撮影画像を角丸 + 影付きで縮小配置。端末フレーム画像は使わない (ライセンスと保守の都合)。
- コピー (ja) は旧ストアの 4 本を流用し、④履歴だけ新規。en は新規。`copy.json` で持ち、人が手直しできるようにする。

**検証 (check)**

- 全出力 PNG の寸法が機種の期待値と一致し、ロケール × 機種 × 画面の枚数 (2 × 2 × 5 = 20) がそろっていることを検証する。
- ルール 8: 寸法を 1px ずらした fixture で RED になることを実証する。
- 目視: ja / en × iPhone / iPad の 4 セットを SendUserFile でユーザーに渡し、合成の見た目の OK をもらう (人の判断点)。

### C. ASC 投入 (skill 実走)

1. `asc-submission-prep` の dry-run (手順 0〜2)。**app ID `1520649806` の URL で開き、書き込み前に毎回ページ上のアプリ名が LeafTimer であることを確認する** (spike でひらがなマッチングゲームを誤って開いた)。
2. 差分表に以下を載せ、判断① (一括 OK) を取る:
   - バージョン 1.5 の新規作成 (skill に無い手順 → D で追記)
   - What's New ja / en
   - スクショ 6.9" / 13" × ja / en
   - ビルド: 1.5 の「提出準備完了」のうち最新 (本 PR merge 後の Xcode Cloud ビルドがあればそれ)
3. 書き込み → 保存 → 再読み込み → 読み戻しで一致を確認する。不一致なら停止する。
4. スクショのアップロードは `mcp__claude-in-chrome__file_upload`。使えなければ停止し、人に手動アップロードを依頼する (ファイルパスを渡す)。
5. 停止レポート (skill の手順 7)。

### D. グローバル skill への還元

- 追記候補: (1) 新バージョンの作成手順 (2) merged PR からの What's New 下書き (3) スクショ投入 (file_upload の可否・順序) (4) ステータス表の更新。
- 追記の直前に `SKILL.md` の mtime と内容を再確認する (並行セッションが編集中の可能性)。LeafTimer 固有値は書かない。

## 5. 物差し

| 物差し | 目標 |
|---|---|
| 実走での人の操作 | OK 1 回 + What's New 手直し + 提出ボタン (ログイン切れ時のみ +1) |
| 書き込み後の読み戻し | 全項目一致 |
| `make store-screenshots` | 20 枚生成・寸法検証 green、寸法 mutation で RED |
| 再現性 | 次回リリースで `make store-screenshots` 1 回 + skill 実走だけで同じ状態に到達できる (次回に検証) |

## 6. リスクと未確認事項

| 項目 | 対処 |
|---|---|
| Simulator のスクショ寸法が Apple 仕様と一致するか | plan 作成時に実測。ずれたら compose 側で仕様寸法に配置するので問題ない (撮影画像は縮小して貼る) |
| 実行中状態・履歴データ・広告を起動引数だけで作れるか | plan 作成時に実機スクショで確認し、必要な DEBUG フックだけ足す (TDD) |
| `file_upload` で ASC のドロップゾーンに投入できるか | 実走で確認。不可なら人の手動アップロードにフォールバック |
| 1.5 作成時に ASC が 1.4 のメタデータを引き継ぐか | 実走の読み戻しで確認 (引き継がなければ差分表を作り直して再 OK) |
| 並行セッションによる skill の同時編集 | D の直前に mtime を確認 |
