# #197 段 1 ASO 文言 (ja / en) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ja / en の名前・サブタイトル・キーワード・説明文・プロモーション用テキストを新しくし、1.6.2 の What's New と合わせて `docs/` に記録した PR を作る。

**Architecture:** コードは変えない。文言の正本は `docs/app-store-metadata.md` (`asc-submission-prep` の入力元) と `docs/RELEASE_v1.6.2.md`。候補はチャットでオーナーに選んでもらい、選ばれた案だけを doc に書く。文字数・重複・禁止語は scratchpad の使い捨てスクリプトで確かめる。ASC への入力と提出は PR の merge 後にコントローラが `asc-submission-prep` で行う (この plan の外)。

**Tech Stack:** Markdown、Python 3 (検証スクリプト、`python3 -I`)、iTunes Search API、claude-in-chrome (ASC の読み取りのみ)。

**Spec:** `docs/superpowers/specs/2026-11-07-issue-197-aso-copy.md`

## Global Constraints

- 名前・サブタイトルは各 30 字以内、キーワードは 100 字以内、プロモーション用テキストは 170 字以内、説明文は 4,000 字以内 (Python の `len()` で数える。ASC の残り字数表示と一致することを 2026-11-07 に確認: キーワード 43 字 → 残り 57)
- 名前の形: `LeafTimer` を先頭に残し、後ろに説明を付ける (`LeafTimer - ○○○` の形)。ja / en とも同じ形
- トーン: 静かでシンプル。届けたい人: 広く「集中したい人」全般
- 絵文字を使わない (ja・en とも ASC が拒否する)。「最強」「No.1」「神」「無料」「Free」、他社アプリ名、「For Kids」系の語を使わない
- 「木を育てる」「森」を主語にしない (Forest の連想を避ける)
- 葉は 1 回のタイマーの進みに合わせて芽 → 若木 → 木と育つ。セッションをまたいで育つ・貯まると読める文を書かない
- 名前・サブタイトル・キーワードの間で同じ語を繰り返さない。キーワードは半角カンマ区切りで、カンマの後に空白を入れない
- 説明文の見出しは ja【】/ en plain text、箇条書きは ja「・」/ en `- `
- アプリ内の表示名 (`CFBundleDisplayName`)・カテゴリ・年齢制限・Review Notes・ストア画像は変えない
- plan の task に PR の merge と ASC への入力を含めない (CLAUDE.md ルール 22)
- PR 本文は `Refs #197` (ストアへの反映は merge 後にしか確かめられない)

## Review Focus

1. 検索結果 1 行で名前 + サブタイトルが端末幅で切れる — 切れても先頭側だけで「ポモドーロの集中タイマー」と伝わること (Task 2 の候補表に「先頭 15 字」の列を置いて確かめる)
2. 全角記号 (`｜`・`・`・`ー`) や半角英字が混ざった文字数 — 30 / 100 / 170 字の上限を Python の `len()` で超えないこと (Task 3 Step 2)
3. 説明文の「育つ」の書き方 — 1 回のタイマー内で育つと読め、セッションをまたいで貯まると読めないこと (Task 3 Step 2 の禁止パターン)
4. キーワードが名前・サブタイトルの語と重複する、カンマの後に空白が入る — 枠の無駄が 0 であること (Task 3 Step 2)
5. 絵文字や装飾記号 (★♪✨) — ASC が保存を拒否するので 0 であること (Task 3 Step 2)

---

### Task 1: 1.6.2 のビルドがあるかを確かめる (読み取りのみ)

**Files:** なし

**Interfaces:**
- Produces: 「1.6.2 のビルド番号と状態 (処理中 / 有効)」または「無い」。コントローラが ASC 入力の段取りに使う

- [ ] **Step 1: Chrome で ASC の TestFlight を開く**

`mcp__claude-in-chrome__tabs_context_mcp` を `createIfEmpty: true` で呼び、`https://appstoreconnect.apple.com/apps/1520649806/testflight/ios` を開く。URL が `/login` に飛んだら止めて、オーナーにログインを頼む (パスワードは入力しない)。

- [ ] **Step 2: 1.6.2 のビルドを読む**

`get_page_text` でビルド一覧を読み、バージョン 1.6.2 の行のビルド番号と状態を記録する。
Expected: 1.6.2 の行がある (PR #198 の merge commit `3ba49ff` で Xcode Cloud が作った想定)。
無ければ: ここで止めて、「Xcode Cloud でビルドを開始してよいか」をオーナーに closed 質問で聞く。開始はオーナーの OK の後。

- [ ] **Step 3: タブを閉じる**

`tabs_close_mcp`。

### Task 2: 文言の候補を作り、オーナーに選んでもらう (人の判断点)

**Files:** なし (案は scratchpad の `aso-candidates.md` に書き、チャットで見せる)

**Interfaces:**
- Consumes: spec の「実測」「文言を作るときの決まり」、Global Constraints
- Produces: オーナーが選んだ ja / en の name・subtitle・keywords・promotional_text・description の確定文 (Task 3 の入力)

- [ ] **Step 1: 説明文に書く機能をコードで確かめる**

次を Read して、機能の事実を表にする: `app/LeafTimer/Components/UserDefaultItem.swift` (`workingTimeList` 5〜60 分、`breakTimeList` 1〜10 分、`soundList` の項目数と中身)、履歴画面の表示項目 (`HistoryViewModel` と履歴の View)、通知 (`NotificationManager` 系)、葉の成長段階 (1.6.1 の #190 の実装)。en の説明文 (`docs/app-store-metadata.md` の en-US description) とずれていたら表に書く。

- [ ] **Step 2: 候補を作る**

- 名前 + サブタイトルの組を 3 案 (ja・en それぞれ)。表の列: 名前 / サブタイトル / 名前の字数 / サブタイトルの字数 / 先頭 15 字 (検索結果で切れても残る部分) / 狙う検索語
- キーワード: 3 案の名前・サブタイトルに含まれない語で 100 字近くまで埋めた案。spec の実測の検索語 (`ポモドーロ` `集中` `タイマー` `勉強` `作業`) が名前・サブタイトル・キーワードのどこかに必ず入ること
- ja 説明文の全文 (1 案)、en 説明文の手直し版 (1 案)、プロモーション用テキスト ja / en (各 1 案)

- [ ] **Step 3: オーナーに選んでもらう**

AskUserQuestion で「名前 + サブタイトルの組 (ja)」「同 (en)」を各 3 択、説明文とプロモーション用テキストは「この文でよい / 直したい」の 2 択で聞く。選ばれた組に合わせてキーワードの重複を除き直す。

### Task 3: 選ばれた文言を docs に書き、機械的に確かめる

**Files:**
- Modify: `docs/app-store-metadata.md` (ja 節に `### name` `### subtitle` `### keywords` `### promotional_text` を足し、ja の description を置き換える。en-US 節の name・subtitle・keywords・description を更新し、`### promotional_text` を足す)
- Create: `docs/RELEASE_v1.6.2.md`

**Interfaces:**
- Consumes: Task 2 の確定文
- Produces: `asc-submission-prep` が読む doc (節の見出しは en-US 節の既存の形 `### name` などにそろえる)

- [ ] **Step 1: doc を書く**

`docs/app-store-metadata.md` に確定文を書く。ja 節の既存の description の形 (コードフェンスで囲む) はそのまま使う。冒頭の箇条書きに「name / subtitle の変更は新しいバージョンの提出が必要 (ASC のアプリ情報ページの注記、2026-11-07)」を 1 行足す。
`docs/RELEASE_v1.6.2.md` を `docs/RELEASE_v1.6.1.md` と同じ構成で作る。What's New は次の文に固定する:
- ja: `・ストアの説明を新しくしました` / `・細かな改善を行いました`
- en: `- Updated the App Store description` / `- Minor improvements`
冒頭の箇条書きに「入力元: v1.6.1 タグ以降の merged PR はバージョン上げ (#198) だけ。文言の変更は #197」と書く。

- [ ] **Step 2: 検証スクリプトで確かめる**

scratchpad に `aso_check.py` を書き、`python3 -I aso_check.py docs/app-store-metadata.md` で実行する。スクリプトは doc の ja / en-US 節から各項目を取り出し、次を ja・en ごとに出力する:
- 字数: name ≤ 30、subtitle ≤ 30、keywords ≤ 100、promotional_text ≤ 170、description ≤ 4000
- name が `LeafTimer` で始まる
- keywords にカンマの後の空白が無い、空要素が無い
- keywords の各語が name・subtitle に部分一致で含まれない (ja は大文字小文字を区別しない比較で en も同様)
- 全項目に絵文字 (`\U0001F000-\U0001FAFF`、`☀-➿`、`⭐`) と `★♪` が無い
- 禁止語が無い: `最強` `No.1` `神` `無料` `Free` `Forest` `森` `For Kids` `子ども向け`
- description に「育てた」「貯ま」「続けるほど」が無い

Expected: 全行が `OK`。1 行でも `NG` なら doc を直して再実行する。
スクリプトが効いていることを確かめるため、一度だけ keywords に `ポモドーロ, 集中` (空白入り) を一時的に足して `NG` が出ることを見てから戻す。

- [ ] **Step 3: make tests を通す**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -30` (Bash timeout 600000)
Expected: `** TEST SUCCEEDED **` があり、`** TEST FAILED **` / `❌` が無い (docs だけの変更だが plan-docs-check が plans/specs の命名を見る)

- [ ] **Step 4: Commit**

```bash
git add docs/app-store-metadata.md docs/RELEASE_v1.6.2.md
git commit -m "docs(#197): ストアの名前・サブタイトル・キーワード・説明文を見直す (ja/en)"
```

### Task 4: spec と plan を archive へ移し、PR を作る

**Files:**
- Move: `docs/superpowers/specs/2026-11-07-issue-197-aso-copy.md` → `docs/superpowers/specs/archive/`
- Move: `docs/superpowers/plans/2026-11-07-issue-197-aso-copy.md` → `docs/superpowers/plans/archive/`

- [ ] **Step 1: git mv して commit**

```bash
git mv docs/superpowers/specs/2026-11-07-issue-197-aso-copy.md docs/superpowers/specs/archive/
git mv docs/superpowers/plans/2026-11-07-issue-197-aso-copy.md docs/superpowers/plans/archive/
git commit -m "docs(#197): spec と plan を archive へ移す"
```

- [ ] **Step 2: 既存 PR を確かめてから PR を作る**

Run: `git fetch && gh pr list --state all --head docs/197-aso-copy`
Expected: 0 件。
`git push -u origin docs/197-aso-copy` の後、`gh pr create --base master`。本文に: 変更した項目の新旧対照 (ja / en)、物差し (spec の基準値と 30 日後の判定)、merge 後に `asc-submission-prep` で 1.6.2 に入力すること、`Refs #197`。
