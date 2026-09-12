# ASC メタデータ投入の自動化スキル化 検討 (Issue #48)

- **Issue**: #48 「ASC申請メタデータ入力の自動化スキル化の『検討』」
- **作成日**: 2026-06-03
- **ブランチ**: `feature/48-asc-metadata-skill`
- **ドキュメントの性質**: これは **「検討フェーズ」の成果物**である。Issue が
  「いきなり実装しないこと」「叩き台を1つに絞り込まず、複数の選択肢とトレードオフを
  並べること」を明示しているため、本書は**1案に収束した実装 spec ではなく、選択肢の
  menu + 各軸の推奨**を提示する。採否は user のレビュー後に決め、実装する場合は
  別途 `writing-plans` で計画を立てる（本検討の終端は「提案提示」であり writing-plans ではない）。

## 目的

App Store Connect（ASC）審査用メタデータ（アプリ名・サブタイトル・説明・キーワード・
リリースノート・スクリーンショット・レビュー情報など）の**入力を自動化**したい。
手段は fastlane `deliver`（= `upload_to_app_store`）を前提とする。

「ASC への情報入力の自動化」は実質「`fastlane/metadata/` 配下の txt 群を整備し、
ワンコマンドで投入する仕組み」に分解できる。これを Claude Code スキルとして整備すべきか、
するならどう設計するかを検討する。

## ブレストで確定した2つの前提（重要な設計入力）

Issue の素案に対し、ブレストで以下2点を user に確認して確定した。これが全軸の判断を縛る。

1. **複数アプリが主目的**。LeafTimer は事実上サンプルで、本命は「複数アプリを継続的に
   回す」ための汎用の仕組み。→ スキルは**最初から app 非依存**設計を優先する（YAGNI の逆で、
   ここは横断 reuse が一次目的なので投資する）。
2. **スキルの責務は「足場 + 投入」のみ**。「喋る → 文字起こし → AI で構造化 → 成果物(txt)」の
   うち、**文字起こし・構造化・文章生成はスコープ外**。スキルは `metadata/` 雛形の用意と
   `deliver` 投入メカニクスだけを担う（執筆済みの文章を入力に取る）。

## 確定済みの技術事実（fastlane `deliver` 公式仕様を verify 済み）

本検討の信頼性の核心。`https://docs.fastlane.tools/actions/deliver/` を参照し確認した。

| 項目 | 確定事実 |
| --- | --- |
| バイナリ投入のスキップ | `skip_binary_upload: true`（デフォルト `false`） |
| 審査提出の制御 | `submit_for_review`（デフォルト `false` = **ステージのみ、審査提出しない**） |
| 非対話（CI）実行 | `force: true` で HTML プレビュー確認をスキップ |
| メタデータ検証 | `precheck` は**スタンドアロン実行可**（`fastlane precheck`、**提出不要**で検証可能）。deliver の `run_precheck_before_submit: true` は **submit フロー前提**で、推奨の stage-only（`submit_for_review: false`）では自動発火しない → 検証は**明示的な `precheck` ステップ**で担保する |
| 雛形生成 | `fastlane deliver init`（download_metadata）が ASC の現状から `metadata/` を**自動 scaffold** |
| 添付ビルド選択 | `build_number` で指定（省略時は対象 version の最新ビルドを自動選択） |

期待されるディレクトリ構造（`fastlane/metadata/` 配下）:

```
metadata/
├── copyright.txt              # 非ローカライズ
├── primary_category.txt       # 非ローカライズ
├── <locale>/                  # 例: en-US, ja
│   ├── name.txt
│   ├── subtitle.txt
│   ├── description.txt
│   ├── keywords.txt
│   ├── release_notes.txt
│   ├── promotional_text.txt
│   ├── support_url.txt
│   ├── marketing_url.txt
│   └── privacy_url.txt
└── review_information/
    ├── first_name.txt
    ├── last_name.txt
    ├── email_address.txt
    ├── phone_number.txt
    ├── demo_user.txt
    ├── demo_password.txt
    └── notes.txt
```

**この検討にとっての含意**: scaffold（`deliver init`）・検証（`precheck`）・投入（`deliver`）は
**fastlane 本体が既に全部持っている**。したがってスキルが新規に足す価値は次の狭い3点に絞られる:

1. **Xcode Cloud 共存の flag レシピ** — バイナリは Xcode Cloud 所有のまま、メタデータだけ push する運用知識。
2. **複数アプリ再利用パターン** — 各 repo の `Appfile`/locale を読む app 非依存の回し方。
3. **検証の合成** — precheck が拾わない穴（英語ロケールの emoji 拒否・version bump）を
   既存スキル `release-version-bump-check` に委譲する。

## このリポジトリの現状

- `app/fastlane/` は既存（`Appfile` / `Fastfile` / `SETUP.md` / `README.md` / `.env.default`）。
- `Fastfile` の lane は `unittests` と **DEPRECATED な `beta`**（TestFlight 用、Issue #13 で Xcode Cloud に移行済み）。
  → **バイナリ配信は Xcode Cloud 所有**。`deliver`/`upload_to_app_store` lane は**現状存在しない**。
- `app/fastlane/metadata/` は**未整備**（greenfield）。
- `Appfile`: `app_identifier "jp.ema.LeafTimer"`、`itc_team_id` / `team_id` 設定済み。
- 既存スキル portfolio: `release-version-bump-check` / `release-retrospective` 等は
  `~/.claude/skills/<name>/SKILL.md` の doc スキル形式（YAML frontmatter + `## Overview`/
  `## When to Use`/`## Core Workflow`(dot図)/`## Step-By-Step`）。本検討の成果はこの慣習に合わせる。

---

# 軸1: そもそもスキル化すべきか（4案 + 推奨）

全体を決める最大の分岐。前提（複数アプリ主目的 / 足場+投入のみ）と「fastlane が
scaffold/検証/投入を既に持つ」事実を踏まえた4案。

| 案 | 形 | Pro | Con |
| --- | --- | --- | --- |
| **A. スキル化しない（repo doc のみ）** | このrepoに `deliver` lane + `metadata/` + 短い README。新アプリは copy-paste | 抽象ゼロ・保守ゼロ。fastlane が重労働を担う | **「複数アプリ主目的」と正面衝突**。copy-paste は drift し、Xcode Cloud 共存の罠を毎回学び直す |
| **B. repo スクリプト + make（アプリ毎）** | 各repoに `bin/asc-metadata.rb` + make target | 機械的部分を自動化、アプリと同居 | 主目的が multi-app なのに**スクリプトを N 個コピー**。gitignore-doctor 型だが、あれは"固有"、今回は"横断"なので reuse を失う |
| **C. グローバル doc スキルのみ** | `~/.claude/skills/asc-metadata-delivery/SKILL.md`。コードは出さず scaffold/配線手順を文書化 | **横断 reuse の know-how**（主目的に一致）。保守する code ゼロ。`release-*` スキル群の既存慣習に一致。app 非依存が自然 | 機械的 step を毎回 Claude が再実行（script より非決定的）。強制チェックなし |
| **D. ハイブリッド（推奨）** | グローバル skill（know-how）+ **薄い** app 非依存ラッパ（metadata-only flag recipe を1コマンド化）+ per-repo の content & 1行 lane | reuse + 機械部分の決定性 + content は各repoに。`release-version-bump-check` と検証を合成 | 設計がやや増える。薄いラッパの物理配置の決定が必要 |

## 推奨: **D（ただし "doc skill 寄りの薄い" D）**

理由は「**fastlane 本体が scaffold(`deliver init`)・検証(`precheck`)・投入(`deliver`)を既に
全部持っている**」点。スキルが新規に足す価値は前掲の狭い3点（共存レシピ / 複数アプリ /
検証合成）だけなので、**大きな custom script（B）は fastlane の再発明になり不要**。
価値が「運用知識」中心なので、**doc skill（C）に薄い1行 lane ラッパだけ足した D** が最小で最大効果。

CLAUDE.md の Issue #10 学び（「機械的かつプロジェクト固有なら doc スキルでなく repo スクリプト」）
とも矛盾しない: 今回は機械部分を**fastlane が既に提供**しており、書くべきは"横断の know-how"=
doc skill 側だから。固有でなく横断であること、機械部分が外部ツール所有であることの2点で
gitignore-doctor（#11）とは判断が分かれる。

> **採否は user のレビューで確定する。** 本書は A〜D の menu を全て残し、D を推奨として提示する。

---

# 軸2: 責務境界 — 1スキルか分割か

**推奨: 新規スキルは1つ。** `scaffold → 整形/検証 → deliver 投入` は「このアプリのメタデータを
押す」という**1つのゴールの線形フロー**で、`metadata/` ディレクトリと `Appfile` という共通
コンテキストを共有する。3スキルに割ると hand-off オーバーヘッドだけ増え、isolation の利得はゼロ。

- **検証は再実装せず `release-version-bump-check` に委譲（参照リンク）**する。
- **却下案**: 「scaffold スキル + deliver スキル」への分割 → scaffold だけ単独で使う場面が無い
  （deliver する意図なしに scaffold しない）ため独立価値がない。

スキル内部の論理ステップ（単一スキル内の手順として）:

1. 前提確認（`Appfile` の識別子・認証情報の存在、対象 version、locale 集合）
2. scaffold（`deliver init` or 既存 `metadata/` の検出）
3. 執筆済み txt の配置確認 + 整形（改行・文字数・空ファイル）
4. 検証（**スタンドアロン** `precheck` + `release-version-bump-check` への委譲。
   stage-only では deliver 内蔵 precheck が走らないため明示実行）
5. metadata-only 投入（`deliver` の共存レシピ）
6. 提出は別ステップ（既定は人間 / opt-in）

---

# 軸3: 入出力定義（「足場 + 投入のみ」前提）

## 入力

- repo の `fastlane/Appfile`（app_identifier・team id・apple_id）
- 対象 App Store version（例: `1.3.0`）
- ロケール集合（例: `ja`, `en-US`）
- **執筆済みの**メタデータ文章（user が手動 / 別ツールで用意したもの）
  - ← **raw 文字起こしは取らない**（軸6 でスコープ外）

## 出力

- scaffold / 検証済みの `fastlane/metadata/<locale>/*.txt` 木
- metadata-only の `deliver` 投入（実行）
- submit 前の precheck / 検証レポート（人間が提出判断するための材料）

## 対象 txt（スキルが面倒を見る範囲）

- locale 毎: `name` / `subtitle` / `description` / `keywords` / `release_notes` /
  `promotional_text` / `support_url` / `marketing_url` / `privacy_url`
- 非ローカライズ: `copyright` / `primary_category`
- `review_information/*`
- スクリーンショット: **パス配線のみ対象**。画像そのものの生成は対象外（軸6）。

---

# 軸4: fastlane との責任分界（核心・verify 済み）

| fastlane が担う | スキル（doc）が担う |
| --- | --- |
| scaffold（`deliver init` / download_metadata） | metadata-only レシピ（`skip_binary_upload: true`）でバイナリを Xcode Cloud に残す |
| 検証（**スタンドアロン** `fastlane precheck`） | 提出ポリシー（`submit_for_review: false` = ステージのみがデフォルト） |
| 投入（`upload_to_app_store`） | CI 安全 flag（`force: true`）、`build_number` でビルド添付 |
| ビルド選択 | precheck の穴（英語 emoji・version bump）を `release-version-bump-check` に合成 |

## 共存の明文化（最重要）

1. **Xcode Cloud** がバイナリを ASC に upload・処理（既存・不変）。
2. スキルの lane が **metadata-only** を push（`skip_binary_upload: true`）。必要なら
   `build_number` で Xcode Cloud がアップした特定ビルドを添付。
3. **審査提出は別の意図的なステップ**。既定は `submit_for_review: false`（ステージのみ）で、
   提出は ASC UI で人間が行う。自動提出したい時だけ明示的に `submit_for_review: true` に opt-in する。

→ **狙い**: メタデータの push がデフォルトで審査を誤発火しないこと。Xcode Cloud（バイナリ）と
deliver（メタデータ）の所有境界を明確に分け、両者が衝突せず共存する。

## 想定する薄い lane（全アプリ共通の3行）

```ruby
lane :upload_metadata do
  # 推奨デフォルトは stage-only。deliver 内蔵 precheck は submit 前提で発火しないため、
  # 検証は precheck を明示ステップとして実行する。
  precheck
  upload_to_app_store(
    skip_binary_upload: true,   # バイナリは Xcode Cloud 所有
    force: true,                # CI/非対話で HTML プレビュー確認をスキップ
    submit_for_review: false    # ステージのみ。提出は意図的な別操作
  )
end
```

> **検証タイミングの注意**: deliver の `run_precheck_before_submit` は **submit フロー前提**で、
> 推奨デフォルトの stage-only（`submit_for_review: false`）では走らない。よって上記のように
> `precheck` を**明示ステップ**として呼ぶ（`precheck` は提出不要のスタンドアロン検証）。
> これで「推奨デフォルトでは検証が走らない」穴を塞ぎ、`release-version-bump-check` との
> 検証合成が無条件で成立する。

---

# 軸5: 複数アプリ再利用設計（主目的）

- **アプリ固有情報は全て各 repo に置く**:
  - `Appfile` = 識別子・team・apple_id
  - `fastlane/metadata/` = メタデータ content
  - locale 集合
- **スキル本体は 100% app 非依存**。実行された repo から上記を読むだけで、スキルに
  アプリ固有値を一切埋め込まない。
- **薄い lane は全アプリ同一**（上記3行）。コピーするか、共有 Fastfile スニペットとして factor out。
- **再利用機構**: SKILL.md をグローバルに**1回 install**。per-app は
  `deliver init` を1回 + 標準 lane を置くだけ。**per-app のスキル複製は無し**。
- 成果物として「**新アプリ オンボーディング 5 ステップ**」チェックリストを SKILL.md に同梱:
  1. `fastlane/Appfile` に識別子・team を設定
  2. 認証情報を `.env`（既存 `SETUP.md` 準拠）に設定
  3. `fastlane deliver init` で `metadata/` を scaffold
  4. 各 locale の txt を執筆して配置
  5. `fastlane upload_metadata` で metadata-only 投入 → ASC UI で提出判断

---

# 軸6: スコープ外（YAGNI / 境界の明示）

- 音声 → 文字起こし、メタデータ文の**生成 / コピーライティング**（手動 / 別ツール）
- スクリーンショット**画像の生成**（パス配線のみ対象）
- バイナリ / ipa の**ビルド・アップロード**（Xcode Cloud 所有）
- version bump / 英語 emoji / age-rating の**チェック実装**（`release-version-bump-check` に委譲）
- ASC 認証情報の**セットアップ**（既存 `app/fastlane/SETUP.md` / `.env` 所有、参照のみ）
- 審査の自動**提出をデフォルト化**すること（提出は既定で人間の意図的操作）

---

# 推奨サマリ（一覧）

| 軸 | 推奨 |
| --- | --- |
| 1. スキル化すべきか | **D**: doc skill 寄りの薄いハイブリッド（A〜D を menu として残す） |
| 2. 責務境界 | 新規スキルは**1つ**。検証は `release-version-bump-check` に委譲 |
| 3. 入出力 | 入力=Appfile/version/locale/**執筆済み**txt、出力=検証済み metadata 木 + metadata-only 投入 + precheck レポート |
| 4. fastlane 分界 | scaffold/検証/投入は fastlane、スキルは**共存レシピ + 提出ポリシー + 検証合成**。`skip_binary_upload:true` / `submit_for_review:false` |
| 5. 複数アプリ | スキルは app 非依存、固有値は各 repo。1回 install + per-app は init & 3行 lane のみ |
| 6. スコープ外 | 文章生成・スクショ画像・バイナリ・既存スキルの再実装・認証 setup・自動提出の既定化 |

# 次のアクション（実装する場合）

本検討は提案提示で終端。user が「案 D（または他案）で進める」と判断した時点で、別途
`superpowers:writing-plans` で実装計画を立てる。実装第一歩の想定:

1. `~/.claude/skills/asc-metadata-delivery/SKILL.md` を既存スキル書式で執筆
   （Overview / When to Use / Core Workflow(dot) / Step-By-Step / 共存レシピ /
   release-version-bump-check への参照 / 新アプリ 5 ステップ）。
2. LeafTimer の `app/fastlane/Fastfile` に `upload_metadata` lane を追加（パイロット適用）。
3. `app/fastlane/metadata/` を `deliver init` で scaffold し、ja / en-US の txt を整備。
4. Xcode Cloud（バイナリ）と共存することを実機 or dry-run で確認。
