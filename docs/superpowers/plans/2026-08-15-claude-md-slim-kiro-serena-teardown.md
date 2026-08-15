# CLAUDE.md スリム化 + Kiro/Serena 一本化 (Issue #83 + #81) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> 本 plan は編集判断が全て plan 内で確定済みの docs-only 作業のため、subagent dispatch せず main セッションで直接実行する (34k 字の元テキストを agent に再投入する意味がなく、#58 の報告ロスト failure mode を持ち込まないため)。

**Goal:** 毎セッション読み込まれる CLAUDE.md (34,310 字) を約 1/4 に圧縮し、凍結した Kiro/Serena ワークフローを撤去して、ドキュメントを実運用 (superpowers 方式) に一本化する。

**Architecture:** (1) 42 の教訓 bullet を処遇表に基づき 1〜2 行ルールへ圧縮し、事故の経緯全文は `docs/claude-lessons-archive.md` へ退避。(2) CLAUDE.md 前半の死んだ Kiro 手順を superpowers 実運用の短い記述に置換。(3) `.kiro/` / `.claude/commands/kiro/` / `.serena/` を `git rm` (tracked なので可逆)、serena 権限は untracked な settings.local.json のローカル side-edit。

**Tech Stack:** Markdown 編集 + git のみ。コード変更なし (`app/` 配下は触らない)。

**Spec:** Issue #83 (https://github.com/es0612/LeafTimer/issues/83) + Issue #81 (https://github.com/es0612/LeafTimer/issues/81)。ユーザー決定 (2026-08-15 AskUserQuestion): Kiro は廃止して畳む / Serena は撤去。

## Global Constraints

- default branch は **master**。ブランチ名: `docs/83-81-claude-md-slim`
- plan doc を実装より前の最初の commit にする (リポ規約)
- 新 CLAUDE.md の目標サイズ: **10,000 字以下** (現 34,310 字)
- 圧縮ルールはコピペ可能な実体 (コマンド・マーカー文字列・パス・値域) を必ず保持する。「教訓の moral だけ残して operational な核を落とす」のが本作業最大の failure mode
- **open issue が参照する教訓は削除禁止** (Dynamic Type 手順→#109/#62/#64、AdMob 観測→#90、BUILT_PRODUCTS_DIR→検証全般)。圧縮のみ可
- アーカイブ先は単一ファイル `docs/claude-lessons-archive.md`。アーカイブ命名規則の一般設計はしない (#84 のスコープ)
- #82 (pending-reflection hook) は**スコープ外**。hook 再設計に踏み込まない
- docs-only なので `make tests` 不要。`app/` を触らないことが条件
- 新 CLAUDE.md にはコードフェンス (バッククォート3連) を含めない (companion-file 教訓のフェンス入れ子事故防止)

---

## 処遇表 (42 bullet 全件)

処遇: **圧縮** = 新 CLAUDE.md に 1〜2 行ルールとして残し全文はアーカイブへ / **統合** = 他 bullet と 1 ルールに併合 / **削除** = ルールとしては残さずアーカイブのみ。新# は後述「新 CLAUDE.md 完成形」のルール番号。

### 失敗からの教訓 (16 bullets)

| 旧 | 内容 | 処遇 | 新# | 理由 |
|----|------|------|-----|------|
| F1 | Edit/Write 失敗→並行セッション疑い | 圧縮 | 13 | 汎用・現役 |
| F2 | SwiftLint custom_rules regex 反転 | 圧縮 | 36 | 現役 (custom rule 追加時に再発しうる) |
| F3 | pipefail / zsh pipestatus / 成功マーカー | 圧縮 | 2 | マーカー文字列と zsh 構文を保持 |
| F4 | plan の tool/path は Glob で実在確認 | 圧縮 | 7 | 現役 |
| F5 | base64 の 76 字折り返し | 圧縮 | 38 | `tr -d '\n'` を保持。低頻度だが再発時致命的 |
| F6 | Explore agent に live/dead 判定 | 圧縮 | 11 | 現役 (triage で毎回使う) |
| F7 | 破壊的操作は literal turn 待ち (#47) | 圧縮 | 14 | 挙動ルールとして重要、2 行で保持 |
| F8 | checker は RED パス実証 | 圧縮 | 8 | 現役 |
| F9 | TDD フォールバックの vacuously green | 圧縮 | 9 | 現役 |
| F10 | MEMORY の過剰一般化禁止 | 圧縮 | 10 | 現役 |
| F11 | Simulator 複数ステップは絶対パス | 圧縮 | 5 | 現役 |
| F12 | make 系は毎回 cd 前置 | 統合 | 1 | F3 と同じ「ビルド/テスト判定規律」に併合 |
| F13 | 判定 grep は実出力を見てから | 圧縮 | 3 | 現役 |
| F14 | zsh --include クォート | 圧縮 | 4 | 現役 |
| F15 | subagent DONE 報告の実地確認 + 生存確認 | 圧縮 | 17 | 直近 #58、SDD で毎回使う |
| F16 | UI 観測前の配線 grep | 圧縮 | 12 | #90 が参照、削除禁止対象 |

### プロジェクト固有の制約 (10 bullets)

| 旧 | 内容 | 処遇 | 新# | 理由 |
|----|------|------|-----|------|
| P1 | Xcode Cloud scheme 警告 false positive | 圧縮 | 34 | 警告自体は今も出る |
| P2 | *.xcworkspace が Package.resolved 巻き込み | 圧縮 | 29 | `git add -f` / whitelist を保持 |
| P3 | make sort を最終 commit 前に | 統合 | 28 | P4 と「新規 Swift ファイル追加時」に併合 |
| P4 | make precheck / orphan baseline 長文 | 圧縮 | 28 | **grandfather 済み 14 orphan の歴史は削除** (baseline 空済み、#83 が名指しした棚卸し対象)。意図判断ルールのみ保持 |
| P5 | ruby gem は rescue LoadError ガード | 圧縮 | 27 | 現役 |
| P6 | 2 層構成 (foo-bar.rb / GIFView) | 圧縮 | 33 | 削除事故防止に現役 |
| P7 | TimerView 背景 4 状態 + material 検証 | 圧縮 | 31 | #63/#64 が参照、simctl コマンド保持 |
| P8 | master default + parallel batch cancel | 分割 | 37, 6 | 「master」と「batch cancel」は別ルールに分ける |
| P9 | Dynamic Type 検証手順 | 圧縮 | 32 | **#109/#62/#64 が参照、削除禁止**。content_size 値域・hasSeenOnboarding・-InitialScreen を全て保持 |
| P10 | ビルド成果物は find で探さない | 圧縮 | 30 | BUILT_PRODUCTS_DIR 取得コマンド保持 |

### 効率化ルール (16 bullets)

| 旧 | 内容 | 処遇 | 新# | 理由 |
|----|------|------|-----|------|
| E1 | dispatch に SendMessage 定型文 | 圧縮 | 15 | SDD で毎回使う |
| E2 | reviewer は report file 二重化 | 統合 | 15 | E1 と同一ルールに併合 |
| E3 | hook は pipe-test してから配線 | 圧縮 | 39 | 現役 |
| E4 | plan を最初の commit に | 圧縮 | 22 | 現役 (本 plan 自身も従う) |
| E5 | push/PR 前に既存 PR 確認 | 圧縮 | 21 | 現役 |
| E6 | 小粒 Task は 1 subagent に束ねる | 圧縮 | 20 | 現役 |
| E7 | subagent の make に timeout 600000 | 圧縮 | 16 | 現役 |
| E8 | CI runner は preinstall 保証なし | 圧縮 | 26 | 現役 |
| E9 | SwiftLint empty_count | 圧縮 | 35 | 現役 |
| E10 | PR 本文にローカル画像不可 | 圧縮 | 25 | 現役 |
| E11 | スキル化候補は機械的か判断的か | 圧縮 | 40 | 現役 |
| E12 | フェンス入り全文は companion 分離 | 圧縮 | 41 | 現役 (本 plan でも適用中) |
| E13 | session limit は別モデル再 dispatch | 圧縮 | 18 | 現役 |
| E14 | Recommendations の routing 必須 | 圧縮 | 19 | 現役 |
| E15 | pr checks はポーリングループ | 圧縮 | 23 | until ループ全文を保持 |
| E16 | Auto-merge 無効 | 圧縮 | 24 | 現役 |

**完全削除はゼロ、部分削除は P4 の grandfather 歴のみ。** 全 bullet の原文はアーカイブに残るため情報ロスなし。

---

## 新 CLAUDE.md 完成形 (Task 3 でこのまま全置換する)

以下がターゲットテキスト。バッククォート3連を含まないため、実行時は Write ツールでこのまま書く。

～～～ ここから ～～～

# LeafTimer 開発ガイド (Claude Code)

## プロジェクト概要

- SwiftUI 製ポモドーロタイマー iOS アプリ。Xcode プロジェクトは `app/` 配下、Bundle ID は `jp.ema.LeafTimer`。
- ビルド/テスト: `cd /Users/shinya/workspace/claude/LeafTimer/app && make tests` (= precheck + unit-tests)。個別ターゲット: `make unit-tests` / `make precheck` / `make sort`。CI/配布は Xcode Cloud。
- 思考は英語、回答の生成は日本語で行う。

## 開発ワークフロー (superpowers 方式)

- セッション開始時に issue から作業を選ぶ時は `daily-issue-triage` skill を使う。
- 機能・修正は brainstorming → writing-plans → subagent-driven-development (または executing-plans) → finishing-a-development-branch の流れ。
- plan は `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` に保存し、ブランチ作成直後・実装より前の最初の commit にする。spec は `docs/superpowers/specs/`。
- 旧 Kiro スタイル SDD (.kiro/) と Serena MCP (.serena/) は 2026-08-15 に廃止した (#81)。経緯と各ルールの事故詳細は `docs/claude-lessons-archive.md` を参照。

## 常時ルール

### Bash・検証の規律

1. ビルド/テスト系コマンドは毎回同一コマンド内で `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する (直前ターンの cwd に依存しない)。成否は exit code でなく出力マーカーで判定: `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` の存在、かつ `** TEST FAILED **` / `Error 6x` / `No rule to make target` の不在。
2. パイプ (`| tail` / `| grep`) は元コマンドの exit code を隠す。shell は zsh なので `${PIPESTATUS[0]}` は無効 (bash 専用) — `set -o pipefail` を前置するか `${pipestatus[1]}` (小文字・1-indexed) を使う。
3. 成否判定の grep パターンは推測で書かず、対象ツールの実際の成功出力を 1 回見てから「成功マーカーの存在 + 失敗マーカーの不在」の両条件で書く (成功メッセージやフラグ名に「error」等が含まれ偽陽性になる)。
4. zsh では `grep --include="*.swift"` のように glob を必ずクォートする。結果が 0 件の時は `no matches found` (コマンド不成立) と「本当に 0 件」を必ず区別する。
5. 複数ステップの Bash (simctl uninstall→install→launch 等) に渡すパスは常に絶対パスで組む (`/Users/shinya/workspace/claude/LeafTimer/app/...`)。直前の `cd` で相対パスが二重化し無言タイムアウトする。
6. parallel Bash batch 内で 1 コマンドが失敗すると同バッチの全コマンドが cancel される。失敗しうる `git checkout` 等と read-only な確認クエリは別バッチに分ける。

### 計画・検証設計

7. plan / spec に書く tool・script・path は、書く前に Glob か Read で実在を 1 回確認する (他 issue コメント等の二次情報を primary 扱いしない)。
8. checker / linter / validator を作る・レビューする時は「意図的に壊した入力で正しく RED になる」ことを fixture で実証する。正常系 GREEN だけの確認は vacuously green。
9. フォールバック分岐を残す実装の RED テストは、新パスに必ず入る前提条件をテスト内で明示的に整え、予測失敗値と実際の失敗値を突き合わせてから GREEN 実装に進む。
10. 教訓・MEMORY を適用する時は literal に禁じている対象だけに適用する (「exit code を信じるな」≠「ツールを使うな」)。広い禁止へ過剰一般化しない。
11. Explore 系 agent に「問題箇所」を報告させる時は、live (production path から参照) / dead の判定を grep で付けさせることを指示書に必ず含める。
12. Simulator で UI 要素の有無を観測する前に、その View の live 参照元を grep して「どの画面に遷移すれば見えるか」を確定させる。
13. Edit/Write の失敗や想定外のファイル変更は、並行セッションによる書き換えをまず疑い、timestamp と内容を確認してから続行する。

### 破壊的操作・agent dispatch

14. 破壊的操作 (rm / git reset / 既存ファイル上書き) はユーザー自身の turn に対象ファイル名が出るまで実行しない。AskUserQuestion の選択肢承認は authorization として扱われない — (i) ユーザーにファイル名を述べてもらう、または (ii) `! rm <path>` で自走してもらう。
15. 全ての agent dispatch (implementer / reviewer / fixer 問わず) の指示書に「最終報告の全文を SendMessage で main へ送信してから idle になる」を明記する。reviewer にはさらに「まず `<workspace>/task-N-review.md` に全文を書き、その後 SendMessage」の二重化を指示する (メッセージ単独では idle 時に本文がロストする)。
16. subagent に `make unit-tests` 等を実行させる時は Bash timeout を 600000 (10 分) にするよう指示書に明記する (デフォルト 2 分では足りない)。
17. subagent の DONE 報告は毎回 `git log --oneline` / `git status --short` / 成果物 mtime で実地確認する。食い違っても即「虚偽」と断じない — mtime とプロセス生存を先に確認し、生きていれば当該 agent に完遂させる (二重 dispatch は silent failure を生む)。
18. subagent が session limit で落ちたら待たず、`model` パラメータで別ティアを指定して同一 prompt を即再 dispatch する。
19. final review の Recommendations は 1 件ずつ行き先 (fix 同梱 / issue 化 / issue コメント / 不採用理由の記録) を決めてから次工程へ進む。silent drop 禁止。
20. 小粒で密結合な Task 群は Task ごとに dispatch せず 1 subagent に束ね、レビューは 2 段階 (spec compliance → code quality) でまとめて行う。

### Git / PR / CI

21. push や `gh pr create` の前に `git fetch && gh pr list --state all --head <branch>` で既存 PR と merge 状況を確認する。
22. plan-driven PR では plan doc を実装より前の最初の commit にする。
23. CI 待ちは `gh pr checks --watch` でなく次のポーリングを使う: `until gh pr checks <PR> --json name,bucket --jq 'all(.[]; .bucket != "pending")' 2>/dev/null | grep -q true; do sleep 30; done`
24. このリポジトリは Auto-merge 無効。CI 完了を確認してから `gh pr merge <PR> --merge` を明示実行する。
25. PR 本文にローカルパスの画像は埋め込めない。スクショは SendUserFile でユーザーに渡し、PR にはユーザーがブラウザで添付する。
26. マネージド CI runner は CocoaPods / Bundler 等の preinstall を保証しない。CI hook の冒頭で `set -euo pipefail` 配下の明示 install を先頭に置く。
27. `make` の依存チェーンに Apple 同梱外の ruby gem 等を足す時は `require` を `rescue LoadError` でガードし、gem 不在でも green を維持する。

### プロジェクト固有の制約

28. 新規 Swift ファイルを追加したら: `make sort` を最終 commit 前に実行 (pbxproj の children 未ソート対策) / `make precheck` で orphan (target 未 attach) を検出。orphan の扱いは liveness grep でなく「放棄→削除 / 配線忘れ→attach」の意図判断で決める (材料は git log の最終更新時期 + live 等価実装の有無)。意図的な orphan は `ruby bin/xcode-precheck.rb --update-baseline` で baseline に追加。
29. `app/.gitignore` の `*.xcworkspace` は `xcshareddata/swiftpm/Package.resolved` を巻き込む。SPM 依存の追加・更新時は `git status` に `Package.resolved` が出るか確認し、出なければ `git add -f` するか `.gitignore` に `!**/Package.resolved` を足す。
30. ビルド成果物 (`.app`) を `find app/build` で探さない (古い残骸を掴み silent に誤検証する)。`xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -showBuildSettings 2>/dev/null | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //'` で実パスを取得する。
31. トップ画面 (`TimerView`) の背景は work/break × light/dark の 4 状態 (`TimerViewModel+extensions.swift` の `getBackgroundColor`)。overlay UI はハードコード色でなく `.ultraThinMaterial` + semantic color を使い、Simulator で 4 状態 (×ロケール) を目視検証する (`xcrun simctl ui <SIM> appearance light|dark` + `-AppleLanguages`)。
32. Dynamic Type 検証は `xcrun simctl ui booted content_size <値>` (標準域 `extra-small`〜`extra-extra-extra-large`、拡張域 `accessibility-medium`〜`accessibility-extra-extra-extra-large` = AX5)。install 直後の初回起動は onboarding の fullScreenCover が最前面に出るため、他画面を撮る前に `xcrun simctl spawn booted defaults write jp.ema.LeafTimer hasSeenOnboarding -bool true` を打つ。onboarding 自体を撮る時は `defaults delete` を使う (`simctl uninstall` は ATT までリセットされるので不可)。tap でしか到達できない画面は起動引数 `-InitialScreen=settings` / `history` / `timePreview` で直接開ける (`TimerView.swift` の DEBUG フック)。設定画面下部はスクロール手段が無く未検証 (#109)。
33. `app/bin/` の `foo-bar.rb` (CLI 層) と `foo_bar.rb` (純粋ロジック、minitest 対象)、`GIFView` (SwiftUI wrapper) と `GIFPlayerView` (UIKit 実体) は意図的な 2 層構成。重複・デッドコードの削除候補にする前に diff と参照確認で層構成かを判定する。
34. Xcode Cloud の "scheme may only exist locally" 警告は、build log に `Cannot find scheme` が無ければ false positive として無視する。
35. SwiftLint `empty_count`: 新規コードは `.isEmpty` を使い、tuple の Int field 等で不可避な場合のみ `// swiftlint:disable:next empty_count` で 1 行 suppress。
36. SwiftLint `custom_rules` の regex は「違反パターン」を書くのが正方向。新規 rule 導入前に正例・反例の両方を列挙してヒット方向の反転がないか確認する。

### 環境・その他

37. このリポジトリの default branch は **master** (`main` ではない)。skill boilerplate の `git checkout main` は失敗する。
38. base64 を CI Secret 等の単一行入力欄に貼る時は `base64 -i <file> | tr -d '\n' | pbcopy` で 1 行化する (デフォルトは 76 字で折り返され silent に壊れる)。
39. 新規 hook スクリプトは settings.json に配線する前に、sample JSON を stdin に pipe-test して bail 条件・self-detach・sentinel ガードを単体検証する。
40. スキル化候補はまず「機械的 (script で検証可能) か判断的か」を見極め、機械的かつプロジェクト固有なら doc スキルでなく repo 内スクリプト + make ターゲットにする。
41. コードフェンス (バッククォート 3 連) を含むファイル全文を plan 内のフェンスに埋め込まない (serialization が壊れる)。companion ファイルに分離してパス参照する。

各ルールの事故経緯・実測データ・Issue 番号付きの詳細は `docs/claude-lessons-archive.md` を参照。

～～～ ここまで ～～～

---

### Task 1: ブランチ作成 + plan commit

**Files:**
- Create: `docs/superpowers/plans/2026-08-15-claude-md-slim-kiro-serena-teardown.md` (本ファイル)

- [ ] **Step 1: master 最新を確認してブランチ作成**

Run: `git checkout master && git pull --ff-only && git checkout -b docs/83-81-claude-md-slim`

- [ ] **Step 2: plan を最初の commit にする**

Run: `git add docs/superpowers/plans/2026-08-15-claude-md-slim-kiro-serena-teardown.md && git commit -m "docs(plan): #83 #81 CLAUDE.md スリム化 + Kiro/Serena 撤去の実装計画"`

### Task 2: 教訓アーカイブ作成

**Files:**
- Create: `docs/claude-lessons-archive.md`

**Interfaces:**
- Produces: 新 CLAUDE.md (Task 3) がフッターでこのパスを参照する

- [ ] **Step 1: アーカイブファイルを作成**

現 CLAUDE.md の「## 振り返りからの学び」配下 3 セクション (失敗からの教訓 / プロジェクト固有の制約 / 効率化ルール) の**全 bullet 原文を無編集で**移設する。冒頭に次の説明を付ける:

- タイトル: `# Claude Code 教訓アーカイブ (CLAUDE.md より退避)`
- 導入 3 行: 「CLAUDE.md の常時ルールの出典となった事故経緯の全文アーカイブ。2026-08-15 の Issue #83 で CLAUDE.md から退避 (ルール本体は CLAUDE.md「常時ルール」参照)。同日 Issue #81 で旧 Kiro スタイル SDD (`.kiro/`、`/kiro:*` コマンド) と Serena MCP (`.serena/`) を廃止・撤去した。」
- 3 セクションの見出しはそのまま維持 (`## 失敗からの教訓` 等)

- [ ] **Step 2: 移設漏れがないことを検証**

Run: `grep -c '^- ' docs/claude-lessons-archive.md`
Expected: 42 (現 CLAUDE.md の教訓 bullet 数と一致。処遇表の 16+10+16)

- [ ] **Step 3: Commit**

Run: `git add docs/claude-lessons-archive.md && git commit -m "docs(claude): #83 教訓全文を docs/claude-lessons-archive.md へ退避"`

### Task 3: CLAUDE.md 全面書き換え

**Files:**
- Modify: `CLAUDE.md` (全置換)

**Interfaces:**
- Consumes: Task 2 のアーカイブパス `docs/claude-lessons-archive.md`

- [ ] **Step 1: 上記「新 CLAUDE.md 完成形」の～～～間テキストで全置換**

Write ツールで CLAUDE.md を完成形テキストに置き換える (Read 済みであること)。

- [ ] **Step 2: サイズと参照を検証**

Run: `wc -c CLAUDE.md && grep -ci 'kiro\|serena' CLAUDE.md && grep -c '^[0-9]*\. ' CLAUDE.md`
Expected: 10,000 字以下 / kiro・serena ヒットは廃止告知行の 2 件のみ / 番号付きルール 41 行

- [ ] **Step 3: Commit**

Run: `git add CLAUDE.md && git commit -m "docs(claude): #83 #81 CLAUDE.md を 1/4 に圧縮し superpowers 実運用へ一本化"`

### Task 4: Kiro / Serena の撤去

**Files:**
- Delete: `.kiro/` (steering 3 + specs 4 ファイル)、`.claude/commands/kiro/` (10 ファイル)、`.serena/` (memories 6 + project.yml + .gitignore)
- Modify: `.gitignore` (3-4 行目の Serena cache 記述を削除)

- [ ] **Step 1: 削除前 SHA を記録 (Task 6 の issue コメントで使う)**

Run: `PRE_DEL_SHA=$(git rev-parse HEAD) && echo $PRE_DEL_SHA` — 値を控える

- [ ] **Step 2: tracked ファイルを git rm**

Run: `git rm -r .kiro .claude/commands/kiro .serena`
注: 全ファイル tracked 確認済み (2026-08-15)。feature branch 上の git rm なので PR reject で完全復元可能。permission prompt が出たら承認を待つ。

- [ ] **Step 3: .gitignore から Serena cache の 2 行を削除**

`.gitignore` の次の 2 行を Edit で削除: `# Serena tooling cache (memories are kept tracked)` と `.serena/cache/`

- [ ] **Step 4: 検証**

Run: `ls .kiro .serena .claude/commands/kiro 2>&1 | grep -c 'No such file'` → Expected: 3
Run: `grep -ri 'kiro\|serena' --exclude-dir=.git --exclude-dir=docs -l . 2>/dev/null` → Expected: `.claude/settings.local.json` のみ (Task 5 で対応、untracked)

- [ ] **Step 5: Commit**

Run: `git add -A && git commit -m "chore: #81 凍結した Kiro workflow と Serena MCP を撤去"`

### Task 5: settings.local.json の serena 権限削除 (ローカル side-edit)

**Files:**
- Modify: `.claude/settings.local.json` (**untracked** — PR diff に出ない。PR 本文に明記する)

- [ ] **Step 1: mcp__serena__* を含む permissions 行を Edit で全削除**

対象は 4-9 行目付近の `mcp__serena__list_dir` 〜 `mcp__serena__read_memory` の 6 行。JSON の配列末尾カンマが壊れないよう前後を確認して削除する。

- [ ] **Step 2: JSON 妥当性を検証**

Run: `python3 -c "import json; json.load(open('.claude/settings.local.json')); print('valid')"`
Expected: `valid`

### Task 6: PR 作成 → CI → merge → issue 後処理

- [ ] **Step 1: 既存 PR 確認と push**

Run: `git fetch && gh pr list --state all --head docs/83-81-claude-md-slim` (空を確認) → `git push -u origin docs/83-81-claude-md-slim`

- [ ] **Step 2: PR 作成**

`gh pr create` で作成。本文に含める: 変更サマリ (34,310 字 → 実測値) / 処遇表は plan 参照 / **「.claude/settings.local.json (untracked) の serena 権限 6 行はローカルで削除済み、diff 外」の明記** / `Closes #83` `Closes #81`

- [ ] **Step 3: CI 完了をポーリングして merge**

Run: `until gh pr checks <PR> --json name,bucket --jq 'all(.[]; .bucket != "pending")' 2>/dev/null | grep -q true; do sleep 30; done && gh pr checks <PR>`
全 pass を確認後: `gh pr merge <PR> --merge` → `git checkout master && git pull --ff-only`

- [ ] **Step 4: #54 / #28 へ移送コメント**

両 issue に投稿: 「旧 Kiro spec `app-modernization-relaunch` を #81 でアーカイブしました (git 履歴 `<PRE_DEL_SHA>` の `.kiro/specs/app-modernization-relaunch/` に全文残存)。spec 残タスクのうち本 issue 相当分 (#54: バックグラウンド動作・通知 / #28: 追加モード) は本 issue が引き続き単一の管理場所です。」

- [ ] **Step 5: クローズ確認**

Run: `gh issue view 83 --json state --jq .state && gh issue view 81 --json state --jq .state`
Expected: 両方 `CLOSED` (PR の Closes で自動クローズ)

---

## Self-Review 済み事項

- spec カバレッジ: #83 の 3 方針 (圧縮 / アーカイブ退避 / 棚卸し) → 処遇表 + Task 2/3。#81 の 4 方針 (前半書き換え / specs 整合 / steering 廃止 / Serena 撤去) → Task 3 / Task 6-Step 4 / Task 4 / Task 4+5。全カバー
- 「アーカイブ」の解釈: spec は docs/ へ移設せず **git rm + 履歴 SHA を issue コメントで参照** とする (764 行の凍結文書を docs に生かしておく価値がないため)。この解釈は plan 承認をもって確定
- 残存参照: README に kiro/serena 参照なし (grep 確認済み)。`.gitignore` は Task 4-Step 3 で対応
- スコープ外の明示: #82 (hook)、#84 (アーカイブ命名規則)、#74 (docs/ver1_2)、steering の現状化はやらない
