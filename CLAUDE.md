# LeafTimer 開発ガイド (Claude Code)

## プロジェクト概要

- SwiftUI 製ポモドーロタイマー iOS アプリ。Xcode プロジェクトは `app/` 配下、Bundle ID は `jp.ema.LeafTimer`。
- ビルド/テスト: `cd /Users/shinya/workspace/claude/LeafTimer/app && make tests` (= precheck + unit-tests)。個別ターゲット: `make unit-tests` / `make precheck` / `make sort`。CI/配布は Xcode Cloud。
- 思考は英語、回答の生成は日本語で行う。

## 開発ワークフロー (superpowers 方式)

- セッション開始時に issue から作業を選ぶ時は `daily-issue-triage` skill を使う。
- 機能・修正は brainstorming → writing-plans → subagent-driven-development (または executing-plans) → finishing-a-development-branch の流れ。
- plan は `docs/superpowers/plans/YYYY-MM-DD-issue-NN[-NN…]-slug.md` (ルール 44) に保存し、ブランチ作成直後・実装より前の最初の commit にする。spec も同じ命名で `docs/superpowers/specs/` に保存する。**`writing-plans` / `brainstorming` skill boilerplate は旧形式 (`YYYY-MM-DD-<feature>.md` / `YYYY-MM-DD-<topic>-design.md`) のパスを出す** — `plan-docs-check` (`make tests` 内、ルール 44) はこれを red にするので、skill が作った直後に厳格な命名へリネームしてから最初の commit にする。
- 旧 Kiro スタイル SDD (.kiro/) と Serena MCP (.serena/) は 2026-08-15 に廃止した (#81)。経緯と各ルールの事故詳細は `docs/claude-lessons-archive.md` を参照。

## 常時ルール

### Bash・検証の規律

1. ビルド/テスト系コマンドは毎回同一コマンド内で `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する。成否は exit code でなく出力マーカーで判定: `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` の存在、かつ `** TEST FAILED **` / `Error 6x` / `No rule to make target` の不在。`Mach error -308 (ipc/mig) server died` / `Lost connection to testmanagerd` 系の FAIL は Simulator インフラ起因の偽 FAIL — コード原因と診断する前に `xcrun simctl shutdown all && killall -9 com.apple.CoreSimulator.CoreSimulatorService` で再起動して 1 回リトライする。
2. パイプ (`| tail` / `| grep`) は元コマンドの exit code を隠す。shell は zsh なので `${PIPESTATUS[0]}` は無効 (bash 専用) — `set -o pipefail` を前置するか `${pipestatus[1]}` (小文字・1-indexed) を使う。
3. 成否判定の grep パターンは推測で書かず、対象ツールの実際の成功出力を 1 回見てから「成功マーカーの存在 + 失敗マーカーの不在」の両条件で書く。**make ターゲット名が既存のディレクトリ／ファイルと同名なら `.PHONY` が必須** (無いと `is up to date` を出して何もせず exit 0 になる)。
4. zsh では `grep --include="*.swift"` のように glob を必ずクォートし、`no matches found` (コマンド不成立) と本当の 0 件を区別する。**このハーネスの `grep` は ripgrep 実装で `.gitignore` を尊重する** — 「参照ゼロ」を主張する検証は `/usr/bin/grep` で取り直す。
5. 複数ステップの Bash (simctl uninstall→install→launch 等) に渡すパスは常に絶対パスで組む (`/Users/shinya/workspace/claude/LeafTimer/app/...`)。直前の `cd` で相対パスが二重化し無言タイムアウトする。
6. parallel Bash batch 内で 1 コマンドが失敗すると同バッチの全コマンドが cancel される。失敗しうる `git checkout` 等と read-only な確認クエリは別バッチに分ける。

### 計画・検証設計

7. plan / spec に書く tool・script・path は、書く前に Glob か Read で実在を確認する。issue 本文の API 前提・依存ツールのバージョン制約演算子や DSL の意味も二次情報 — Apple docs の `curl` 原文やツール自身の API で実測してから書く (`~> 0.10.3` は patch を固定しない)。**plan に貼るコード片は `ruby -c` / `ruby -ryaml` の構文確認に加え、plan に貼る逐語のコードそのもので scratchpad 実行し、期待値 (テスト件数・assertion 数・mutation の failure 数・実データでの RED 件数) を実測してから書く** — plan に「この数値と違ったら止めて報告」と書き、implementer はその数字で成否を判定する (minitest は `assert_includes` / `assert_empty` を 2 assertions と数える)。
8. checker / linter / validator を作る・レビューする時は「意図的に壊した入力で正しく RED になる」ことを fixture で実証する (正常系 GREEN だけは vacuous)。mutation は「新規・強化したテスト 1 件 : mutation 1 つ以上」の対応表で網羅し、設計前に「どの入力がその分岐を通るか」を確認する。**受け入れ手順の検証コマンド自体が効くかも確かめる**: スクリプトが ARGV を読むか、その make ターゲットが `tests` チェーンに入っているか。**ローカル green は CI をモデルしない** — setup-ruby の `vendor/bundle` 隔離など CI 固有の挙動は action のソースを `curl` で読んでから結論する。実時間依存テストの `XCTNSPredicateExpectation(object: nil)` は約 1 秒ポーリングなので、timeout は「発火予定時刻 + 数秒」、下限アサーションは初回発火を predicate で待ってから delta 判定する。
9. フォールバック分岐を残す実装の RED テストは、新パスに必ず入る前提条件をテスト内で明示的に整え、予測失敗値と実際の失敗値を突き合わせてから GREEN 実装に進む。
10. 教訓・MEMORY を適用する時は literal に禁じている対象だけに適用する (「exit code を信じるな」≠「ツールを使うな」)。広い禁止へ過剰一般化しない。
11. Explore 系 agent に「問題箇所」を報告させる時は、live (production path から参照) / dead の判定を grep で付けさせることを指示書に必ず含める。
12. Simulator で UI 要素の有無を観測する前に、View の live 参照元を grep して遷移先を確定させる → skill `leaftimer-simulator-verification`。
13. Edit/Write の失敗や想定外のファイル変更は、並行セッションによる書き換えをまず疑い、timestamp と内容を確認してから続行する。**subagent の稼働中、コントローラは `git checkout` / `git pull` / `git switch` など HEAD を動かすコマンドを実行しない** (同じ working directory を共有し、agent の未 commit 作業を巻き込む)。稼働中の確認は `git log <ref>` / `git show <ref>:<path>` / `git diff <a>..<b>` の読み取りに限り、reviewer 系 agent の指示書にも同じ禁止を書く。分離が必要なら git worktree を使う。

### 破壊的操作・agent dispatch

14. 破壊的操作 (rm / git reset / 既存ファイル上書き) はユーザー自身の turn に対象ファイル名が出るまで実行しない。AskUserQuestion の選択肢承認は authorization として扱われない — ユーザーにファイル名を述べてもらうか、`! rm <path>` で自走してもらう。**削除を提案する最初のメッセージで、そのまま貼れる `! git rm -r <path>` (未追跡なら `! rm <path>`) を必ず添える**。例外: `.claude/pending-reflection.md` は SessionStart hook の指示に基づき、AskUserQuestion の選択結果 (追記する / 追記しない) を authorization として削除してよい。
15. 全ての agent dispatch (implementer / reviewer / fixer 問わず) の指示書に「最終報告の全文を SendMessage で main へ送信してから idle になる」を明記する。reviewer にはさらに「まず `<workspace>/task-N-review.md` に全文を書き、その後 SendMessage」の二重化を指示する (メッセージ単独では idle 時に本文がロストする)。
16. subagent に `make unit-tests` 等を実行させる時は Bash timeout を 600000 (10 分) にするよう指示書に明記する。**subagent は自分が起動した background Bash の完了を待つと idle になり、完了通知では自動再開しない** — controller が同じログを `until grep -q <終端マーカー> <log>; do sleep 15; done` の background Bash で監視し、完了時に SendMessage で起こす (指示書にもそう書いておく)。
17. subagent の DONE 報告は毎回 `git log --oneline` / `git status --short` / 成果物 mtime で実地確認する。食い違っても即「虚偽」と断じない — mtime とプロセス生存を先に確認し、生きていれば当該 agent に完遂させる (二重 dispatch は silent failure を生む)。
18. subagent が session limit で落ちたら待たず、`model` パラメータで別ティアを指定して同一 prompt を即再 dispatch する。
19. final review の Recommendations は 1 件ずつ行き先 (fix 同梱 / issue 化 / issue コメント / 不採用理由の記録) を決めてから次工程へ進む。silent drop 禁止。
20. 小粒で密結合な Task 群は Task ごとに dispatch せず 1 subagent に束ね、レビューは 2 段階 (spec compliance → code quality) でまとめて行う。

### Git / PR / CI

21. push や `gh pr create` の前に `git fetch && gh pr list --state all --head <branch>` で既存 PR と merge 状況を確認する。
22. plan-driven PR では plan doc を実装より前の最初の commit にする。**plan の task に PR merge ステップを含めない** — plan は「PR 作成まで」で切り、merge はレビュー通過後にコントローラがルール 24 のチェーンで行う (implementer が merge まで走ると、レビュー指摘が merge 済みコードに対して出る)。
23. CI 待ちは **フォアグラウンドの `gh run watch <run-id> --interval 30`** を run ごとに実行する (run ID は `gh pr checks <PR>` の URL 末尾)。`--watch` / sleep ポーリング / バックグラウンドの完了通知・Monitor イベントは使わない (sleep 無効、通知は早発・偽発しうる)。watch は結論行を出さないことがあるので、完了後に必ず `gh pr checks <PR>` で再確認する。**CI 設定 (workflow / Makefile) を変える PR は green でなくログのメッセージパターンで受け入れる**: `gh run view <id> --log | grep -E "<期待メッセージ>"` (step 列は `UNKNOWN STEP` になりうるので step 名では grep しない)。`rescue LoadError` 系ガード付き checker は「✅ 行の存在」+「`skipped` 行の不在」を条件にする。
24. このリポジトリは Auto-merge 無効。merge は非同期通知を根拠にせず、必ず `gh pr checks <PR> && gh pr merge <PR> --merge` の同一チェーンで行う。**checks 全 pass かつ final review 済みなら、このチェーン自体が事前承認済み — merge 前に AskUserQuestion を挟まない**。auto mode クラシファイアにブロックされたら同一チェーンを 1 回リトライし、だめならユーザーに `! gh pr merge <PR> --merge` を依頼する。
25. PR 本文にローカルパスの画像は埋め込めない。スクショは SendUserFile でユーザーに渡し、PR にはユーザーがブラウザで添付する。
26. CI の CocoaPods/Bundler は明示 install し、常に `bundle exec pod …` (`app/Gemfile.lock` 固定)。素の `pod` に戻さない → skill `leaftimer-xcode-deps`。
27. make チェーンの ruby checker に gem を足す時は `rescue LoadError` ガード + CI では `bundle exec make tests` で包み ✅ 行を受け入れ基準にする → skill `leaftimer-xcode-deps`。

### プロジェクト固有の制約

28. Swift ファイル追加は `make add-file FILE=… TARGET=app|test` (手編集禁止、配線は同じ commit に含める)。target/SPM 参照の削除と orphan の扱い → skill `leaftimer-xcode-deps`。
29. SPM 依存の追加・更新時は `Package.resolved` が `git status` に出るか確認する (`*.xcworkspace` の ignore に巻き込まれる) → skill `leaftimer-xcode-deps`。
30. `.app` を `find app/build` で探さない。`-showBuildSettings` の `BUILT_PRODUCTS_DIR` で実パスを取る → skill `leaftimer-simulator-verification`。
31. トップ画面の背景は work/break × light/dark の 4 状態。overlay は `.ultraThinMaterial` + semantic color にし 4 状態 (×ロケール) を目視する → skill `leaftimer-simulator-verification`。
32. Dynamic Type・onboarding/ATT の回避・起動引数 (`-InitialScreen` / `-LeafPattern`)・cliclick の tap・通知バナー・アニメ判定・スクショ原寸目視 → skill `leaftimer-simulator-verification`。
33. `app/bin/` の `foo-bar.rb` (CLI 層) と `foo_bar.rb` (純粋ロジック、minitest 対象)、`GIFView` (SwiftUI wrapper) と `GIFPlayerView` (UIKit 実体) は意図的な 2 層構成。重複・デッドコードの削除候補にする前に diff と参照確認で層構成かを判定する。
34. Xcode Cloud の "scheme may only exist locally" 警告は、build log に `Cannot find scheme` が無ければ false positive として無視する。
35. SwiftLint `empty_count`: 新規コードは `.isEmpty` を使い、tuple の Int field 等で不可避な場合のみ `// swiftlint:disable:next empty_count` で 1 行 suppress。
36. SwiftLint `custom_rules` の regex は「違反パターン」を書くのが正方向。新規 rule 導入前に正例・反例の両方を列挙してヒット方向の反転がないか確認する。

### 環境・その他

37. このリポジトリの default branch は **master** (`main` ではない)。skill boilerplate の `git checkout main` は失敗する。
38. base64 を CI Secret 等の単一行入力欄に貼る時は `base64 -i <file> | tr -d '\n' | pbcopy` で 1 行化する (デフォルトは 76 字で折り返され silent に壊れる)。
39. 新規 hook スクリプトは settings.json に配線する前に、sample JSON を stdin に pipe-test して bail 条件・self-detach・sentinel ガードを単体検証する。
40. スキル化候補はまず「機械的 (script で検証可能) か判断的か」を見極め、機械的かつプロジェクト固有なら doc スキルでなく repo 内スクリプト + make ターゲットにする。
41. コードフェンス (バッククォート 3 連) を含むファイル全文を plan 内のフェンスに埋め込まない (serialization が壊れる)。companion ファイルに分離してパス参照する。長い plan は Write で末尾が silent に切れることがあるので、commit 前に `/usr/bin/grep -c '^```' <plan>` が偶数であることを確認する。
42. レイアウト変更が既存デザインか回帰か迷ったら `docs/ver1_2/screen/` の旧ストアスクショと突き合わせる → skill `leaftimer-simulator-verification`。
43. テストは新規は XCTest、View 構造は ViewInspector。Quick/Nimble は新規追加禁止・既存は据え置き。Podfile の制約と `pod update` の注意 → skill `leaftimer-xcode-deps`。
44. plan / spec のファイル名は `YYYY-MM-DD-issue-NN[-NN…]-slug.md` (slug は小文字英数とハイフン。companion は `….SKILL-source.md` のように suffix を足す)。**`plans/` `specs/` 直下は「plan を書いてから `gh pr create` するまで」の一時置き場**で、plan の最終タスクで `git mv` して `archive/` へ移してから `gh pr create` する。`archive/` は「PR 作成済み」を意味し、稼働中かはファイルの場所でなく branch/PR の状態で判断する (`archive/` は日付プレフィックスのみ要求)。`make plan-docs-check` (tests チェーン内) が命名と、直下に 14 日より長く置かれた滞留 (ファイル名の日付で判定) を fail させる。issue 未起票の題材は先に `gh issue create` してから保存する (`drafts/` 等の逃げ道は作らない)。
45. CLAUDE.md にルールを新設・改訂する時は、**同じ話題を扱う既存行を `/usr/bin/grep` して自己矛盾を潰してから commit する**。その規約に従うファイルを生成する plugin skill の boilerplate (`writing-plans` / `brainstorming` 等。repo からは直せない) が旧形式を出さないかも確認し、出す場合はルール 37 と同じ形で「skill はこう出すので最初の commit 前に直せ」と明記する。**CLAUDE.md は 18,000B 上限** (`make claude-md-size-check`、tests チェーン内)。超えたら事故の経緯は `docs/claude-lessons-archive.md` へ、作業時だけ要る手順は `.claude/skills/` へ移す。

各ルールの事故経緯・実測データ・Issue 番号付きの詳細は `docs/claude-lessons-archive.md` を参照。
