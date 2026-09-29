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

1. ビルド/テスト系コマンドは毎回同一コマンド内で `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する (直前ターンの cwd に依存しない)。成否は exit code でなく出力マーカーで判定: `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` の存在、かつ `** TEST FAILED **` / `Error 6x` / `No rule to make target` の不在。`Mach error -308 (ipc/mig) server died` / `Lost connection to testmanagerd` 系の FAIL は Simulator インフラ起因の偽 FAIL — コード原因と診断する前に `xcrun simctl shutdown all && killall -9 com.apple.CoreSimulator.CoreSimulatorService` で再起動して 1 回リトライする (PR #134 のセッションで 3 回発生、全て再起動で回復)。
2. パイプ (`| tail` / `| grep`) は元コマンドの exit code を隠す。shell は zsh なので `${PIPESTATUS[0]}` は無効 (bash 専用) — `set -o pipefail` を前置するか `${pipestatus[1]}` (小文字・1-indexed) を使う。
3. 成否判定の grep パターンは推測で書かず、対象ツールの実際の成功出力を 1 回見てから「成功マーカーの存在 + 失敗マーカーの不在」の両条件で書く (成功メッセージやフラグ名に「error」等が含まれ偽陽性になる)。 **make ターゲット名が既存のディレクトリ／ファイルと同名なら `.PHONY` が必須** — 無いと make は `is up to date` を出して何も実行せず exit 0 になる (PR #165 の `store-screenshots` ターゲットが入力ディレクトリ `store-screenshots/` と同名で発生。✅ 行の不在で気づけた)。
4. zsh では `grep --include="*.swift"` のように glob を必ずクォートする。結果が 0 件の時は `no matches found` (コマンド不成立) と「本当に 0 件」を必ず区別する。**このハーネスの `grep` は ripgrep 実装で `.gitignore` を尊重する** — 「参照ゼロ」を主張する検証は `/usr/bin/grep` で取り直す (PR #140 の reviewer が `.superpowers/` のヒット欠落を実測)。
5. 複数ステップの Bash (simctl uninstall→install→launch 等) に渡すパスは常に絶対パスで組む (`/Users/shinya/workspace/claude/LeafTimer/app/...`)。直前の `cd` で相対パスが二重化し無言タイムアウトする。
6. parallel Bash batch 内で 1 コマンドが失敗すると同バッチの全コマンドが cancel される。失敗しうる `git checkout` 等と read-only な確認クエリは別バッチに分ける。

### 計画・検証設計

7. plan / spec に書く tool・script・path は、書く前に Glob か Read で実在を 1 回確認する (他 issue コメント等の二次情報を primary 扱いしない)。issue 本文の API 前提も二次情報 — checker に encode する前に Apple docs を `curl` で原文確認する (#108 の「`Font.custom(size:)` は固定サイズ」は誤りで、固定になるのは `fixedSize:` — PR #144 の task review で判明)。plan に書くコード片は `ruby -c` / `ruby -ryaml` で構文確認する (`/…/x` regex のコメント内 `/`、YAML plain scalar の ` #` で plan 逐語が壊れた — PR #144)。 **依存ツールのバージョン制約演算子・DSL の意味も同じ二次情報** — 推測で書かず、ツール自身の API で実測する (`~> 0.10.3` を「patch まで固定」と plan に書いたが実際は `>= 0.10.3, < 0.11.0` で patch は素通りする。final review が `Pod::Requirement` で実測して発覚 — PR #156)。**plan に貼るコード片は構文確認だけでなく scratchpad で実行し、期待値 (テスト件数・mutation の failure 数・実データでの RED 件数) を実測してから書く** — implementer はその数字を成否判定に使うので、推測値だと「期待と違う」で停止する (PR #156 は 35 件 RED / 11 runs / mutation 3・2 failures をすべて実測値で plan に記載した)。 **その実測は plan に貼る逐語のコードで行う** — プロトタイプで測った値を plan の別バージョンに載せない (PR #158 は assertion 数を 53 と書いたが実測は 54。minitest は `assert_includes` / `assert_empty` を内部の `assert_respond_to` 込みで 2 assertions と数え、plan 版のテストにはプロトタイプより assert が 1 件多かった。plan には「この数値と違ったら止めて報告」と書くので、ズレは implementer を確実に止める)。
8. checker / linter / validator を作る・レビューする時は「意図的に壊した入力で正しく RED になる」ことを fixture で実証する。正常系 GREEN だけの確認は vacuously green。**mutation の対象は「新規に強化した全テスト」に広げる** (#133 の a11y 2 件だけ未実証で final review 指摘、PR #137)。また mutation を設計する前に「どの入力がその分岐を通るか」を確認する — plan 指定の sentinel 定数変更は既存テストが実在キーしか見ないため 1 件も波及せず、lproj path 解決の破壊に切り替えて 12 件同時 fail を取得した (PR #137)。実時間依存テストでは `XCTNSPredicateExpectation(object: nil)` が約 1 秒ポーリングなので timeout は「発火予定時刻 + 数秒」の余裕を取り、固定時間窓での下限アサーションは「初回発火を predicate で待ってから delta 判定」にする (PR #140 の `DefaultTimerManagerTests`)。 **ローカル green は CI をモデルしない**: ローカルの `bundle install` (path 未設定) は gem を global gem dir に入れるので「素の `ruby -e 'require …'` が通った」は setup-ruby の `vendor/bundle` 隔離 (CI) では成り立たない。CI 固有の隔離・PATH 差し替えは action のソースを `curl` で原文確認してから結論する (PR #146 の Task 1 がこの誤結論を書き、final review が setup-ruby の bundler.js を読んで回帰を発見)。 **受け入れ手順を書く前に、その検証コマンド自体が効くかを確認する**: (i) スクリプトが ARGV を読むか (`bin/gitignore-doctor.rb` は `FIXTURE_FILE` をハードコードし引数を無視するので「引数で fixture を差し替えて確認した」は vacuous — PR #158 で実測)、(ii) その make ターゲットが `tests` チェーンに含まれるか (`gitignore-check` は入っていない → #159)。mutation の網羅は「新規テスト 1 件 : mutation 1 つ以上」の対応表で確認する (PR #158 は新規 7 件のうち 1 件が未実証で、その未実証テストが守っていた 1 行が Important 欠陥の唯一のガードだった)。
9. フォールバック分岐を残す実装の RED テストは、新パスに必ず入る前提条件をテスト内で明示的に整え、予測失敗値と実際の失敗値を突き合わせてから GREEN 実装に進む。
10. 教訓・MEMORY を適用する時は literal に禁じている対象だけに適用する (「exit code を信じるな」≠「ツールを使うな」)。広い禁止へ過剰一般化しない。
11. Explore 系 agent に「問題箇所」を報告させる時は、live (production path から参照) / dead の判定を grep で付けさせることを指示書に必ず含める。
12. Simulator で UI 要素の有無を観測する前に、View の live 参照元を grep して遷移先を確定させる → skill `leaftimer-simulator-verification`。
13. Edit/Write の失敗や想定外のファイル変更は、並行セッションによる書き換えをまず疑い、timestamp と内容を確認してから続行する。**subagent の稼働中、コントローラは `git checkout` / `git pull` / `git switch` など HEAD を動かすコマンドを実行しない** — subagent は同じ working directory を共有しており、agent の未 commit 作業を巻き込む (#70 で実測: PR merge 後の master 同期が実装 agent の HEAD を移動させた)。稼働中の状態確認は `git log <ref>` / `git show <ref>:<path>` / `git diff <a>..<b>` の読み取り専用に限定し、reviewer 系 agent の指示書にも同じ禁止を明記する。分離が必要なら git worktree を使う。

### 破壊的操作・agent dispatch

14. 破壊的操作 (rm / git reset / 既存ファイル上書き) はユーザー自身の turn に対象ファイル名が出るまで実行しない。AskUserQuestion の選択肢承認は authorization として扱われない — (i) ユーザーにファイル名を述べてもらう、または (ii) `! rm <path>` で自走してもらう。**削除を提案する最初のメッセージで、そのまま貼れる `! git rm -r <path>` (未追跡なら `! rm <path>`) を必ず添える** — 対象一覧だけ見せて「OK」をもらい、その後にコマンドを案内すると往復が 1 回増える (#163 / PR #174 で実測)。例外: `.claude/pending-reflection.md` は SessionStart hook の指示に基づき、AskUserQuestion の選択結果 (追記する / 追記しない) を authorization として削除してよい (#82)。
15. 全ての agent dispatch (implementer / reviewer / fixer 問わず) の指示書に「最終報告の全文を SendMessage で main へ送信してから idle になる」を明記する。reviewer にはさらに「まず `<workspace>/task-N-review.md` に全文を書き、その後 SendMessage」の二重化を指示する (メッセージ単独では idle 時に本文がロストする)。
16. subagent に `make unit-tests` 等を実行させる時は Bash timeout を 600000 (10 分) にするよう指示書に明記する (デフォルト 2 分では足りない)。 **subagent は自分が起動した background Bash (xcodebuild 等) の完了を待つと idle になり、完了通知では自動再開しない** — controller が同じログを `until grep -q <終端マーカー> <log>; do sleep 15; done` の background Bash で監視し、完了時に SendMessage で「完了した、次の Step へ」と起こす (PR #150 の Task 2 で 3 回実測。指示書に「background 実行後 idle になったら controller が起こす」と書いておく)。
17. subagent の DONE 報告は毎回 `git log --oneline` / `git status --short` / 成果物 mtime で実地確認する。食い違っても即「虚偽」と断じない — mtime とプロセス生存を先に確認し、生きていれば当該 agent に完遂させる (二重 dispatch は silent failure を生む)。
18. subagent が session limit で落ちたら待たず、`model` パラメータで別ティアを指定して同一 prompt を即再 dispatch する。
19. final review の Recommendations は 1 件ずつ行き先 (fix 同梱 / issue 化 / issue コメント / 不採用理由の記録) を決めてから次工程へ進む。silent drop 禁止。
20. 小粒で密結合な Task 群は Task ごとに dispatch せず 1 subagent に束ね、レビューは 2 段階 (spec compliance → code quality) でまとめて行う。

### Git / PR / CI

21. push や `gh pr create` の前に `git fetch && gh pr list --state all --head <branch>` で既存 PR と merge 状況を確認する。
22. plan-driven PR では plan doc を実装より前の最初の commit にする。**plan の task に PR merge ステップを含めない** — subagent-driven-development ではタスクレビューが完了ゲートなので、implementer が merge まで走るとレビュー指摘が常に merge 済みコードに対して出て、追随 commit が必要になる (#66 で実測)。plan は「PR 作成まで」で切り、merge はレビュー通過後にコントローラがルール 24 のチェーンで行う。
23. CI 待ちは `gh pr checks --watch` や `until ... sleep 30` ポーリングでなく、**フォアグラウンドの `gh run watch <run-id> --interval 30`** を run ごとに実行する (run ID は `gh pr checks <PR>` の URL 末尾から取る)。この環境の Bash は sleep が無効でターン内待機できず、バックグラウンドタスクの完了通知や Monitor イベントは早発・偽発しうる (PR #111 で実行中ジョブの偽 pass イベントを実測)。**`gh run watch` は成功時に結論行を出さず、ジョブログの末尾 (brew の tap-trust 警告など) で終わることがある** — watch の出力だけで pass と判断せず、完了後に必ず `gh pr checks <PR>` で pass/fail を再確認する (PR #126 / #127 の pr-tests で 2 回とも結論行なしを実測)。**CI 設定 (workflow / Makefile) を変える PR は green check でなく当該 step のログ行で受け入れる** — `gh run view <id> --log | grep "^pr-tests	<step 名>"` で期待メッセージ (例: `✅ cocoapods … available` / `LeafTimer.app NN%`) を確認する。summary 系 step は入力欠落でも exit 0 するため、green は「何も出なかった」と区別できない (PR #144)。 **`gh run view --log` の step 列は `UNKNOWN STEP` になることがある** — `grep "^pr-tests\t<step 名>"` は precheck 等の出力を取りこぼすので、受け入れはメッセージパターン (`grep -E "ruby 3\.4\.4|cocoapods via bundler|lock-check passed|targets: no new orphan"`) で grep する。`rescue LoadError` 系ガード付き checker は「✅ 行の存在」に加えて「`skipped` 行の不在」も条件に入れる (run 33930722131 で実測)。
24. このリポジトリは Auto-merge 無効。merge は非同期通知を根拠にせず、必ず `gh pr checks <PR> && gh pr merge <PR> --merge` の同一チェーンで再検証をゲートにして実行する。 **checks 全 pass かつ final review 済みなら、このチェーン自体が事前承認済みの操作 — merge 前に AskUserQuestion を挟まない** (PR #134 で「確認できているなら直接マージできませんか」と押し返された)。`gh pr merge` が auto mode クラシファイアにブロックされることがあるが transient — 同一チェーンを 1 回リトライしてからユーザーに `! gh pr merge <PR> --merge` を依頼する (PR #136 で 2 回目に成功)。
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
41. コードフェンス (バッククォート 3 連) を含むファイル全文を plan 内のフェンスに埋め込まない (serialization が壊れる)。companion ファイルに分離してパス参照する。 **長い plan を Write すると末尾が silent に切れることがある** (PR #146 の plan は Task 3 途中で切れ、追記時に閉じフェンスが 1 行欠落)。plan の commit 前に `/usr/bin/grep -c '^```' <plan>` が偶数であることを確認する。
42. レイアウト変更が既存デザインか回帰か迷ったら `docs/ver1_2/screen/` の旧ストアスクショと突き合わせる → skill `leaftimer-simulator-verification`。
43. テストは新規は XCTest、View 構造は ViewInspector。Quick/Nimble は新規追加禁止・既存は据え置き。Podfile の制約と `pod update` の注意 → skill `leaftimer-xcode-deps`。
44. plan / spec のファイル名は `YYYY-MM-DD-issue-NN[-NN…]-slug.md` (slug は小文字英数とハイフン。companion は `….SKILL-source.md` のように suffix を足す)。**`plans/` `specs/` 直下は「plan を書いてから `gh pr create` するまで」の一時置き場**で、plan の最終タスクで `git mv` して `archive/` へ移してから `gh pr create` する (#84。「merge 後に別 commit で片付ける」設計にすると 34 件溜まった実績がある)。**`archive/` は「PR 作成済み」を意味する** — merge 済みの歴史だけでなく、PR 作成後 merge 前の in-flight な plan もここに同居する。実際に稼働中かどうかはファイルの場所ではなく branch/PR の状態で判断する。`archive/` 配下は日付プレフィックスのみを要求する (旧規則で書かれた歴史はリネームしない)。`make plan-docs-check` (tests チェーン内) がこの命名を検証し、あわせて**直下に 14 日より長く置かれた plan/spec を滞留として fail させる** (#153。判定は mtime でなくファイル名の日付プレフィックス)。厳格名は保存前に issue 番号を要求するので、**issue 未起票の題材は先に `gh issue create` してから** plan/spec を保存する (`drafts/` のような逃げ道は作らない)。
45. CLAUDE.md にルールを新設・改訂する時は、**同じ話題を扱う既存行を `/usr/bin/grep` して自己矛盾を潰してから commit する**。ルール 44 (plan 命名) を追加した際、同じファイルの 13 行目が旧命名 `YYYY-MM-DD-<feature>.md` を指示したままで、新設した `make plan-docs-check` ゲートが次の plan-driven PR を最初の commit で確実に赤にする状態だった (final review が検出 — PR #156)。あわせて、その規約に従うファイルを**生成する plugin skill の boilerplate** (`writing-plans` / `brainstorming` 等。`~/.claude/plugins/cache/` 配下で repo からは直せない) が旧形式を出さないか確認し、出す場合はルール 37 と同じ形で「skill はこう出すので最初の commit 前に直せ」と明記する。

各ルールの事故経緯・実測データ・Issue 番号付きの詳細は `docs/claude-lessons-archive.md` を参照。
