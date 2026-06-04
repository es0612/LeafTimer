# ASC メタデータ投入スキル (採用案D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App Store Connect のメタデータ投入を、app 非依存のグローバル doc スキル + 全アプリ共通の薄い `upload_metadata` lane + per-repo の metadata content として整備する（採用案D = doc 寄りの薄いハイブリッド）。

**Architecture:** fastlane `deliver`/`upload_to_app_store` が scaffold・検証・投入を全部持つ前提で、スキルが新規に足す価値は〈Xcode Cloud 共存レシピ / 複数アプリ reuse / 検証合成〉の3点のみ。バイナリは Xcode Cloud 所有のまま、`skip_binary_upload:true` で metadata だけを stage(`submit_for_review:false`) push する。検証 (`precheck`) と実投入は **ASC 認証必須 = 本番 ASC に書き込む** ため、自動化せず operator 手動 runbook に隔離する。

**Tech Stack:** fastlane 2.228.0 (homebrew, `deliver`/`precheck`/`upload_to_app_store`), Claude Code doc skill (`~/.claude/skills/<name>/SKILL.md`), 既存スキル `release-version-bump-check` への検証委譲。

**設計ソース:** `docs/superpowers/specs/2026-06-03-asc-metadata-skill-design.md`（採用案D 確定）。

---

## この plan の最重要構造: 2部構成

| | Part 1 — repo 側 (この PR) | Part 2 — operator runbook |
| --- | --- | --- |
| 性質 | offline / committable / CI 検証可 | ASC 認証必須 / 本番 ASC に書き込む / 手動 |
| 内容 | Fastfile lane・metadata skeleton・gitignore・repo doc・(別物として) グローバル SKILL.md | `deliver download_metadata`・`precheck`・`upload_metadata` 実行・共存確認 |
| 実行者 | subagent / executing-plans が自動実行してよい | 人間が認証情報を持って手で実行。subagent / CI は実行しない |
| 不可逆性 | なし | あり（`upload_to_app_store` は `submit_for_review:false` でも metadata を live ASC に stage する。"submit しない" だけで "書き込まない" ではない） |

この境界は安全のための必須分割であり、scope のサボりではない。Part 2 の各ステップは「touches production ASC — 認証付きで人間が手実行」と明示する。Part 1 の Task は subagent が回してよいが、Part 2 は runbook（文書）であって subagent が実行する Task ではない。

### グローバル SKILL.md の置き場所 (検証済み事実)

`~/.claude/skills` は git 管理外（親をたどっても `.git` なし。`git -C ~/.claude/skills rev-parse` が fatal）。よって SKILL.md はグローバルファイルで LeafTimer の PR には含まれない。Task 1 はグローバルファイルを書く作業で `git commit` は無い（LeafTimer repo の外）。LeafTimer の PR に入るのは Task 2〜4（lane / metadata / docs）のみ。

---

# Part 1 — repo 側 (offline / committable)

## File Structure

| ファイル | 配置 | git | 責務 |
| --- | --- | --- | --- |
| `~/.claude/skills/asc-metadata-delivery/SKILL.md` | グローバル | 管理外 (PR 外) | app 非依存の know-how（共存レシピ・新アプリ5ステップ・検証委譲） |
| `app/fastlane/Fastfile` | repo | commit | 全アプリ共通の薄い `upload_metadata` lane を追加 |
| `app/fastlane/metadata/**` (content txt) | repo | commit | per-repo の執筆メタデータ置き場 (placeholder skeleton) |
| `app/fastlane/metadata/review_information/*` | repo | gitignore (secret) | demo 認証情報など。`.gitkeep` のみ commit |
| `app/.gitignore` | repo | commit | `review_information` の secret 除外 |
| `app/fastlane/SETUP.md` | repo | commit | metadata 投入手順 + Xcode Cloud 共存 + Part 2 runbook へのポインタ |
| `app/fastlane/README.md` | repo | commit | fastlane 自動再生成 (新 lane が載る) |

---

## Task 1: グローバル SKILL.md を執筆 (PR 外・global file)

**Files:**
- Create: `~/.claude/skills/asc-metadata-delivery/SKILL.md` (グローバル。LeafTimer repo の外)

> このタスクは git commit を伴わない（`~/.claude/skills` は VC 管理外）。検証は「frontmatter が valid YAML」「dot グラフが構文として閉じている」「ファイルが読める」の3点。

- [ ] **Step 1: ディレクトリを作成**

Run:
```
mkdir -p ~/.claude/skills/asc-metadata-delivery
```

- [ ] **Step 2: SKILL.md を書く (全文)**

SKILL.md の全文は companion ファイル `docs/superpowers/plans/2026-06-04-issue-48-asc-metadata-skill.SKILL-source.md` に確定済み（frontmatter から最後まで丸ごとが本体）。そのままコピーする:

```
cp docs/superpowers/plans/2026-06-04-issue-48-asc-metadata-skill.SKILL-source.md \
   ~/.claude/skills/asc-metadata-delivery/SKILL.md
```

> プレースホルダなし: SKILL.md 本体は companion ファイルに完全な形で存在する。編集はそちらに対して行い、再度 `cp` する。

- [ ] **Step 3: frontmatter と dot を検証**

Run:
```
head -5 ~/.claude/skills/asc-metadata-delivery/SKILL.md
grep -c '\[shape=' ~/.claude/skills/asc-metadata-delivery/SKILL.md
```
Expected: 1〜5 行目に `---` / `name: asc-metadata-delivery` / `description:` / `---` が出る。`[shape=` が複数ヒット。

- [ ] **Step 4: commit はしない (global file)**

このファイルは `~/.claude/skills`（git 管理外）なので commit 不要。次の Task 2 から LeafTimer repo の変更に入る。

---

## Task 2: `upload_metadata` lane を Fastfile に追加

**Files:**
- Modify: `app/fastlane/Fastfile`（`platform :ios do ... end` 内、`beta` lane の後）
- Regenerate: `app/fastlane/README.md`（fastlane が自動再生成）

- [ ] **Step 1: lane を追記**

`app/fastlane/Fastfile` の `lane :beta do ... end` ブロックの直後（platform の `end` の前）に、次を挿入:

```
  desc "Push listing metadata only to App Store Connect (binary stays with Xcode Cloud)"
  # 認証必須・本番 ASC に metadata を stage する。CI/自動では実行しない (operator 手動)。
  # 詳細手順は SETUP.md「ASC メタデータ投入」と
  # ~/.claude/skills/asc-metadata-delivery/SKILL.md を参照。
  lane :upload_metadata do
    # 先に metadata を ASC の editable に stage する (skip_binary_upload で binary は触らない)。
    # force は付けない: この lane は人間が手実行する前提なので、本番書き込み前に
    # deliver の HTML プレビューを人間が確認する gate を意図的に残す。
    upload_to_app_store(
      skip_binary_upload: true,   # バイナリは Xcode Cloud 所有
      submit_for_review: false    # ステージのみ。提出は意図的な別操作
    )
    # precheck はローカルではなく ASC 側 (editable) を検証する (metadata_path オプション無し)。
    # よって upload の後に呼び、いま stage したコピーを人間 submit 前に検証する。
    precheck
  end
```

> 設計 doc (`2026-06-03-...-design.md`, merged) は precheck → upload の順で書かれていたが、計画時に `fastlane action precheck` を実測し **precheck はローカルではなく ASC 側 editable を検証する (metadata_path 無し)** と判明したため、**upload → precheck に訂正**した。precheck を upload 前に置くと「これから push する新コピー」ではなく「古い ASC コピー」を検証してしまうため。

- [ ] **Step 2: lane が parse され一覧に載るか検証 (offline)**

Run:
```
cd app && fastlane lanes 2>&1 | grep -A1 upload_metadata
```
Expected: `ios upload_metadata` と desc 行が出力される（`fastlane lanes` は Fastfile を parse するだけで ASC 認証不要）。Ruby syntax / undefined エラーが出ないこと。

> 注: この実行で `app/fastlane/README.md` が自動再生成され `upload_metadata` の項が追記される。`update_fastlane`（Fastfile 先頭）が走るため初回はネット確認が入るが lane 一覧自体は offline 取得。

- [ ] **Step 3: commit**

```
cd /Users/shinya/workspace/claude/LeafTimer
git add app/fastlane/Fastfile app/fastlane/README.md
git commit -m "feat(fastlane): #48 add metadata-only upload_metadata lane"
```

---

## Task 3: metadata skeleton + gitignore (secret 除外)

**Files:**
- Create: `app/fastlane/metadata/copyright.txt`, `primary_category.txt`
- Create: `app/fastlane/metadata/ja/*.txt`（9 ファイル）
- Create: `app/fastlane/metadata/en-US/*.txt`（9 ファイル）
- Create: `app/fastlane/metadata/review_information/.gitkeep`
- Modify: `app/.gitignore`（`review_information` の secret 除外を追記）

> placeholder の中身は全て literal token `PLACEHOLDER` を含める。これは安全装置: 万一 download せず upload しても precheck の `placeholder_text` ルールが RED にする。operator は最初に `deliver download_metadata` で live 内容に上書きする。

- [ ] **Step 1: ディレクトリと placeholder txt を生成**

Run:
```
cd /Users/shinya/workspace/claude/LeafTimer/app/fastlane
mkdir -p metadata/ja metadata/en-US metadata/review_information
printf 'PLACEHOLDER\n' > metadata/copyright.txt
printf 'PLACEHOLDER\n' > metadata/primary_category.txt
for loc in ja en-US; do
  for key in name subtitle description keywords release_notes promotional_text; do
    printf 'PLACEHOLDER (run `fastlane deliver download_metadata` first)\n' > "metadata/$loc/$key.txt"
  done
  for url in support_url marketing_url privacy_url; do
    printf 'https://example.com/PLACEHOLDER\n' > "metadata/$loc/$url.txt"
  done
done
printf '' > metadata/review_information/.gitkeep
```

- [ ] **Step 2: 生成物を確認**

Run:
```
cd /Users/shinya/workspace/claude/LeafTimer
find app/fastlane/metadata -type f | sort
```
Expected: copyright.txt / primary_category.txt / ja の9 txt / en-US の9 txt / review_information/.gitkeep の計 21 ファイル。

- [ ] **Step 3: `.gitignore` に review_information の secret 除外を追記**

`app/.gitignore` の fastlane セクション末尾（現状 `fastlane/.env` の行の後）に追記:

```
# ASC review demo credentials などの機微情報は commit しない (dir 構造は .gitkeep のみ)
fastlane/metadata/review_information/*
!fastlane/metadata/review_information/.gitkeep
```

- [ ] **Step 4: gitignore が意図どおりか検証（`git add -n` で確認。check-ignore の exit code は使わない）**

> MEMORY: `git check-ignore` の exit code は `!` whitelist で信頼できない。staging に実際に乗るかは `git add --dry-run` で見る。

Run:
```
cd /Users/shinya/workspace/claude/LeafTimer
printf 'SECRET\n' > app/fastlane/metadata/review_information/demo_password.txt
git add -n app/fastlane/metadata/review_information 2>&1
rm app/fastlane/metadata/review_information/demo_password.txt
```
Expected: dry-run 出力に `.gitkeep` は現れる（whitelist 有効）が `demo_password.txt` は現れない（正しく ignore）。

- [ ] **Step 5: commit**

```
cd /Users/shinya/workspace/claude/LeafTimer
git add app/.gitignore app/fastlane/metadata
git commit -m "chore(fastlane): #48 scaffold metadata skeleton + gitignore review_information secrets"
```

---

## Task 4: repo doc 更新 (SETUP.md に投入手順 + 共存 + runbook ポインタ)

**Files:**
- Modify: `app/fastlane/SETUP.md`（「ASC メタデータ投入」セクションを追記）

- [ ] **Step 1: SETUP.md に章を追記**

`app/fastlane/SETUP.md` の「## 利用可能なレーン」セクションの後（「## トラブルシューティング」の前）に挿入。内容（要点）:
- バイナリは Xcode Cloud 所有のまま metadata だけ投入する lane であること。
- 警告: `upload_metadata` は本番 ASC に書き込む（`submit_for_review:false` は submit しないだけで書き込みは起きる）。人間が手実行、CI/自動で走らせない。
- 手順 download → edit → precheck → upload（`fastlane deliver download_metadata` で live 取得 → `ja`/`en-US` 編集 → 検証 → `fastlane upload_metadata`）。
- en-US は emoji 禁止 / 文字数制限、version bump・en-emoji・Age Rating は `release-version-bump-check` に委譲。
- `review_information/` は gitignore 済み（`.gitkeep` のみ commit）。各自ローカルで埋める。

実際の挿入テキストは Part 2 runbook（R1〜R7）と整合させ、SETUP.md の既存トーン（番号付き手順）に合わせて書く。

- [ ] **Step 2: Markdown が壊れていないか確認**

Run:
```
cd /Users/shinya/workspace/claude/LeafTimer
grep -n "ASC メタデータ投入" app/fastlane/SETUP.md
```
Expected: 追記した見出しが1件ヒット。

- [ ] **Step 3: commit**

```
cd /Users/shinya/workspace/claude/LeafTimer
git add app/fastlane/SETUP.md
git commit -m "docs(fastlane): #48 document metadata-only upload workflow + Xcode Cloud coexistence"
```

---

## Part 1 完了後

repo PR を作成可能（branch 例: `feature/48-asc-metadata-skill-impl`）。PR には Task 2〜4 の3コミットが載る。グローバル SKILL.md（Task 1）は PR 外。`project.pbxproj` 変更は無い（Xcode project にファイルを足していない）が、push 前に `git status` で uncommitted が無いことを確認する。

---

# Part 2 — Operator Runbook (認証必須 / 本番 ASC に書き込む / 手動)

> これは subagent / executing-plans が実行する Task ではない。人間が ASC 認証情報を持って手で実行する手順書。各ステップは production ASC に対する操作。

### R1. 認証情報を用意
`app/fastlane/.env`（gitignore 済み）に `FASTLANE_USER` + App-Specific Password、または ASC API Key を設定（`SETUP.md` 参照）。

### R2. live メタデータを download（ASC read）
```
cd app && fastlane deliver download_metadata
```
placeholder（`PLACEHOLDER` token）が live 内容で上書きされる。これが安全な出発点。

### R3. content を編集
`fastlane/metadata/ja|en-US/*.txt` を執筆済み文章で更新。`review_information/*` を埋める。en の emoji 禁止・文字数制限・version bump を `release-version-bump-check` スキルで確認。

### R4. ローカル検証（upload 前に潰す。RED を実証）
> 「壊れた入力で正しく RED になるか」を実証する（CLAUDE.md の checker 教訓）。precheck は ASC 側しか見ず metadata_path も無いので fixture には使えない。代わりに `release-version-bump-check` が担う **en-emoji** はローカルファイルを見れば offline で RED 化できる。本物の metadata は壊さない（一時 fixture に対してのみ）。
```
# GREEN: 本物の en-US には emoji が無い (placeholder は ASCII のみ) → ヒット0
grep -lP '[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}]' app/fastlane/metadata/en-US/*.txt; echo "exit=$?"
# RED demo: わざと emoji を入れた fixture を作り、検出されることを確認
printf 'Bug fixes and improvements ✨\n' > /tmp/en-bad.txt
grep -lP '[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}]' /tmp/en-bad.txt && echo "RED: emoji detected (correct)"
rm /tmp/en-bad.txt
```
Expected: 本物の en-US は exit=1（ヒット0 = emoji 無し）。fixture は `RED: emoji detected (correct)` が出る（= 壊れた入力が正しく RED）。version bump (pbxproj) と Age Rating は `release-version-bump-check` スキル本体の手順で確認する。precheck 自体（ASC 側 staged コピー検査）は R5 の upload 後に lane 内で走る。

### R5. metadata-only を投入（本番 ASC に書き込む — confirm 必須）
```
cd app && fastlane upload_metadata
```
lane は `upload_to_app_store`（`skip_binary_upload:true` でバイナリは触らず metadata を editable に stage、`submit_for_review:false`）→ その後 `precheck` で stage 済みコピーを検証、の順に走る。precheck が違反を出したら R3 に戻って修正・再 upload。

### R6. ASC UI で確認 → 人間が submit 判断
App Store Connect で stage された metadata を目視確認し、問題なければ UI から審査提出。自動提出したい時だけ lane を `submit_for_review:true` に opt-in（既定は人間操作）。

### R7. Xcode Cloud 共存の確認
同バージョンのバイナリが Xcode Cloud で processing 済みであること、`upload_metadata` がバイナリを置き換えていないことを ASC のビルド一覧で確認。

---

# Self-Review

**1. Spec coverage（設計 doc 6軸との突合）:**
- 軸1（スキル化=D）→ Task 1（グローバル doc skill）+ Task 2（薄い lane）。
- 軸2（責務境界=1スキル・検証は委譲）→ SKILL.md「検証の合成」+ `release-version-bump-check` 委譲。
- 軸3（入出力）→ Task 3 skeleton + Part 2 runbook。
- 軸4（fastlane 分界・共存レシピ）→ Task 2 lane の3フラグ + SKILL.md。
- 軸5（複数アプリ・新アプリ5ステップ）→ SKILL.md。
- 軸6（スコープ外）→ SKILL.md「スコープ外」節。

**2. Placeholder scan:** plan 内に "TBD" / "後で実装" 等は無し。metadata の `PLACEHOLDER` は意図的な安全装置（precheck tripwire）。

**3. Type / 名前整合:** lane 名は全箇所 `upload_metadata`。skill 名は `asc-metadata-delivery`。locale は `ja` / `en-US`。フラグ名 `skip_binary_upload` / `submit_for_review` / `force` は fastlane 公式と一致。

**4. 安全境界:** ASC に書き込む操作（precheck / upload）は全て Part 2（手動・認証）に隔離。Part 1 は offline のみ。

**5. precheck データ源の実測訂正:** `fastlane action precheck` を実測し、precheck は `check_app_store_metadata` のエイリアスで `metadata_path` 非対応 = **ASC 側 editable を検証**すると確認。設計 doc の precheck→upload を **upload→precheck に訂正**し、SKILL.md / lane / Common Mistakes / Core Workflow を全て整合。offline RED demo は precheck（ASC 必須）ではなく en-emoji の local grep（`release-version-bump-check` 委譲分）で実証する形に変更。

---

### Appendix: SKILL.md 全文

SKILL.md の全文は別ファイルに確定済み（plan markdown 内に二重 code fence を埋めると壊れるため分離）:

→ `docs/superpowers/plans/2026-06-04-issue-48-asc-metadata-skill.SKILL-source.md`

先頭の `---` frontmatter から末尾の「## Pairs With」まで全てがファイル本体。Task 1 Step 2 でそのまま `cp` する。lane コード / フラグ / 安全注記は本 plan の Task 2・Part 2 runbook と一致済み。
