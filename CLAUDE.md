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

1. ビルド/テスト系コマンドは毎回同一コマンド内で `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する (直前ターンの cwd に依存しない)。成否は exit code でなく出力マーカーで判定: `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` の存在、かつ `** TEST FAILED **` / `Error 6x` / `No rule to make target` の不在。`Mach error -308 (ipc/mig) server died` / `Lost connection to testmanagerd` 系の FAIL は Simulator インフラ起因の偽 FAIL — コード原因と診断する前に `xcrun simctl shutdown all && killall -9 com.apple.CoreSimulator.CoreSimulatorService` で再起動して 1 回リトライする (PR #134 のセッションで 3 回発生、全て再起動で回復)。
2. パイプ (`| tail` / `| grep`) は元コマンドの exit code を隠す。shell は zsh なので `${PIPESTATUS[0]}` は無効 (bash 専用) — `set -o pipefail` を前置するか `${pipestatus[1]}` (小文字・1-indexed) を使う。
3. 成否判定の grep パターンは推測で書かず、対象ツールの実際の成功出力を 1 回見てから「成功マーカーの存在 + 失敗マーカーの不在」の両条件で書く (成功メッセージやフラグ名に「error」等が含まれ偽陽性になる)。
4. zsh では `grep --include="*.swift"` のように glob を必ずクォートする。結果が 0 件の時は `no matches found` (コマンド不成立) と「本当に 0 件」を必ず区別する。**このハーネスの `grep` は ripgrep 実装で `.gitignore` を尊重する** — 「参照ゼロ」を主張する検証は `/usr/bin/grep` で取り直す (PR #140 の reviewer が `.superpowers/` のヒット欠落を実測)。
5. 複数ステップの Bash (simctl uninstall→install→launch 等) に渡すパスは常に絶対パスで組む (`/Users/shinya/workspace/claude/LeafTimer/app/...`)。直前の `cd` で相対パスが二重化し無言タイムアウトする。
6. parallel Bash batch 内で 1 コマンドが失敗すると同バッチの全コマンドが cancel される。失敗しうる `git checkout` 等と read-only な確認クエリは別バッチに分ける。

### 計画・検証設計

7. plan / spec に書く tool・script・path は、書く前に Glob か Read で実在を 1 回確認する (他 issue コメント等の二次情報を primary 扱いしない)。issue 本文の API 前提も二次情報 — checker に encode する前に Apple docs を `curl` で原文確認する (#108 の「`Font.custom(size:)` は固定サイズ」は誤りで、固定になるのは `fixedSize:` — PR #144 の task review で判明)。plan に書くコード片は `ruby -c` / `ruby -ryaml` で構文確認する (`/…/x` regex のコメント内 `/`、YAML plain scalar の ` #` で plan 逐語が壊れた — PR #144)。
8. checker / linter / validator を作る・レビューする時は「意図的に壊した入力で正しく RED になる」ことを fixture で実証する。正常系 GREEN だけの確認は vacuously green。**mutation の対象は「新規に強化した全テスト」に広げる** (#133 の a11y 2 件だけ未実証で final review 指摘、PR #137)。また mutation を設計する前に「どの入力がその分岐を通るか」を確認する — plan 指定の sentinel 定数変更は既存テストが実在キーしか見ないため 1 件も波及せず、lproj path 解決の破壊に切り替えて 12 件同時 fail を取得した (PR #137)。実時間依存テストでは `XCTNSPredicateExpectation(object: nil)` が約 1 秒ポーリングなので timeout は「発火予定時刻 + 数秒」の余裕を取り、固定時間窓での下限アサーションは「初回発火を predicate で待ってから delta 判定」にする (PR #140 の `DefaultTimerManagerTests`)。 **ローカル green は CI をモデルしない**: ローカルの `bundle install` (path 未設定) は gem を global gem dir に入れるので「素の `ruby -e 'require …'` が通った」は setup-ruby の `vendor/bundle` 隔離 (CI) では成り立たない。CI 固有の隔離・PATH 差し替えは action のソースを `curl` で原文確認してから結論する (PR #146 の Task 1 がこの誤結論を書き、final review が setup-ruby の bundler.js を読んで回帰を発見)。
9. フォールバック分岐を残す実装の RED テストは、新パスに必ず入る前提条件をテスト内で明示的に整え、予測失敗値と実際の失敗値を突き合わせてから GREEN 実装に進む。
10. 教訓・MEMORY を適用する時は literal に禁じている対象だけに適用する (「exit code を信じるな」≠「ツールを使うな」)。広い禁止へ過剰一般化しない。
11. Explore 系 agent に「問題箇所」を報告させる時は、live (production path から参照) / dead の判定を grep で付けさせることを指示書に必ず含める。
12. Simulator で UI 要素の有無を観測する前に、その View の live 参照元を grep して「どの画面に遷移すれば見えるか」を確定させる。
13. Edit/Write の失敗や想定外のファイル変更は、並行セッションによる書き換えをまず疑い、timestamp と内容を確認してから続行する。**subagent の稼働中、コントローラは `git checkout` / `git pull` / `git switch` など HEAD を動かすコマンドを実行しない** — subagent は同じ working directory を共有しており、agent の未 commit 作業を巻き込む (#70 で実測: PR merge 後の master 同期が実装 agent の HEAD を移動させた)。稼働中の状態確認は `git log <ref>` / `git show <ref>:<path>` / `git diff <a>..<b>` の読み取り専用に限定し、reviewer 系 agent の指示書にも同じ禁止を明記する。分離が必要なら git worktree を使う。

### 破壊的操作・agent dispatch

14. 破壊的操作 (rm / git reset / 既存ファイル上書き) はユーザー自身の turn に対象ファイル名が出るまで実行しない。AskUserQuestion の選択肢承認は authorization として扱われない — (i) ユーザーにファイル名を述べてもらう、または (ii) `! rm <path>` で自走してもらう。例外: `.claude/pending-reflection.md` は SessionStart hook の指示に基づき、AskUserQuestion の選択結果 (追記する / 追記しない) を authorization として削除してよい (#82)。
15. 全ての agent dispatch (implementer / reviewer / fixer 問わず) の指示書に「最終報告の全文を SendMessage で main へ送信してから idle になる」を明記する。reviewer にはさらに「まず `<workspace>/task-N-review.md` に全文を書き、その後 SendMessage」の二重化を指示する (メッセージ単独では idle 時に本文がロストする)。
16. subagent に `make unit-tests` 等を実行させる時は Bash timeout を 600000 (10 分) にするよう指示書に明記する (デフォルト 2 分では足りない)。
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
26. マネージド CI runner は CocoaPods / Bundler 等の preinstall を保証しない。CI hook の冒頭で `set -euo pipefail` 配下の明示 install を先頭に置く。**CocoaPods は `app/Gemfile.lock` で固定し常に `bundle exec pod …` で動かす** (#143。Ruby は `app/.ruby-version`、CI は `ruby/setup-ruby@v1` の `working-directory: app` + `bundler-cache: true` が両方を読む)。素の `pod` / `gem install cocoapods` / `pod _<ver>_` に戻さない — macos runner の `pod` は brew ruby の RubyGems binstub で**常に最新 install 版を activate する**ため lock 版へ downgrade できない (PR #144 で実測)。Gemfile.lock と Podfile.lock の `COCOAPODS:` 行の一致は `make cocoapods-lock-check` (tests チェーン内) が守る。Xcode Cloud の `ci_post_clone.sh` は master 限定トリガーで PR 検証できないため #143 のフォローアップ (未着手)。
27. `make` の依存チェーンに Apple 同梱外の ruby gem 等を足す時は `require` を `rescue LoadError` でガードし、gem 不在でも green を維持する。 **ただしガードは CI で silent green を生みうる** — `ruby/setup-ruby@v1` の `bundler-cache: true` は gem を `app/vendor/bundle` (deployment mode) に隔離し自身の Ruby を PATH 先頭に置くため、後続 step の素の `ruby bin/*.rb` は lock の gem を `require` できず、ガードが黙って skip する (PR #146 final review I-1: orphan gate が `⚠️ skipped` のまま green)。CI では `bundle exec make tests` のように **make ごと bundle exec で包み**、ガード付き checker の ✅ 行を受け入れ基準に入れる。

### プロジェクト固有の制約

28. 新規 Swift ファイルの pbxproj 配線は手編集せず **`make add-file FILE=<project相対パス> TARGET=app|test`** を使う (#130 で整備。sort + precheck まで自動実行、idempotent)。TARGET は必須 — app/test の取り違えは「テストが本番バイナリに入る」事故になる。配線 (pbxproj 差分) を**そのファイルを追加する commit 自体に含める** (pbxproj の children 未ソート対策。「最終 commit 前」に後送りすると task review で指摘され fix round が 1 つ増える — PR #115 で実測) / `make precheck` で orphan (target 未 attach) を検出。orphan の扱いは liveness grep でなく「放棄→削除 / 配線忘れ→attach」の意図判断で決める (材料は git log の最終更新時期 + live 等価実装の有無)。意図的な orphan は `ruby bin/xcode-precheck.rb --update-baseline` で baseline に追加。**`make add-file` は未配線 .swift が複数並存する状態で `&&` 連結できない** — 1 回目の内部 precheck が 2 つ目を orphan 判定して exit 2 で止まる。1 ファイルずつ実行する (PR #137 で実測)。**target 削除も手編集せず xcodeproj gem の one-off で行う**が、`target.remove_from_project` は `XCBuildConfiguration` と `TargetAttributes` (UUID キーで target 名の文字列を含まない) を連鎖削除しない — 受け入れは文字列 grep でなく構造検査 (`TargetAttributes.keys - targets.map(&:uuid) == []`、参照 UUID ⊆ 定義 UUID) で行い、`pod install && make sort` を 2 回回して pbxproj が安定することを確認する (PR #140 で実測: grep は `remaining refs: 0` を返したが残骸 2 種あり)。 **この構造検査は `make pbxproj-structure-check` (precheck 内、#73 で repo 化) が行う** — SPM 参照の除去も同じ gem の one-off (`frameworks_build_phase.remove_build_file` → `package_product_dependencies.delete` + `remove_from_project` → `root_object.package_references.delete` + `remove_from_project`) で行い、検証は fresh な `-derivedDataPath` で `xcodebuild test` を回して `SourcePackages/checkouts` が生成されないことを実測する (既定 DerivedData の stale な SPM 成果物がリンク切れを隠す — #73)。
29. `app/.gitignore` の `*.xcworkspace` は `xcshareddata/swiftpm/Package.resolved` を巻き込む。SPM 依存の追加・更新時は `git status` に `Package.resolved` が出るか確認し、出なければ `git add -f` するか `.gitignore` に `!**/Package.resolved` を足す。
30. ビルド成果物 (`.app`) を `find app/build` で探さない (古い残骸を掴み silent に誤検証する)。`xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -showBuildSettings 2>/dev/null | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //'` で実パスを取得する。同名 Simulator が複数世代ある機種 (iPhone SE 等) では `name=...,OS=latest` は曖昧マッチで exit 70 になる — `xcrun simctl list devices available` で UDID を引き、`-destination "platform=iOS Simulator,id=<UDID>"` で指定する (#113 で実測)。
31. トップ画面 (`TimerView`) の背景は work/break × light/dark の 4 状態 (`TimerViewModel+extensions.swift` の `getBackgroundColor`)。overlay UI はハードコード色でなく `.ultraThinMaterial` + semantic color を使い、Simulator で 4 状態 (×ロケール) を目視検証する (`xcrun simctl ui <SIM> appearance light|dark` + `-AppleLanguages`)。
32. Dynamic Type 検証は `xcrun simctl ui booted content_size <値>` (標準域 `extra-small`〜`extra-extra-extra-large`、拡張域 `accessibility-medium`〜`accessibility-extra-extra-extra-large` = AX5)。install 直後の初回起動は onboarding の fullScreenCover が最前面に出るため、他画面を撮る前に `xcrun simctl spawn booted defaults write jp.ema.LeafTimer hasSeenOnboarding -bool true` を打つ。onboarding 自体を撮る時は `defaults delete` を使う (`simctl uninstall` は ATT までリセットされるので不可)。tap でしか到達できない画面は起動引数 `-InitialScreen=settings` / `history` / `timePreview` で直接開ける (`TimerView.swift` の DEBUG フック)。葉パターンは `-LeafPattern=small|mid|big` で強制できる (#64)。fresh Simulator では初回起動時に **ATT ダイアログ**が最前面に出て simctl では tap も TCC.db 直書きもできない — `applesimutils --byId <UDID> --bundle jp.ema.LeafTimer --setPermissions "userTracking=YES" --restartSB` で事前付与してから起動する (brew 導入済み。再導入時は `brew trust wix/brew` が必要)。設定画面下部はスクロール手段が無く未検証 (#109)。simctl に tap は無いが、**`cliclick c:<x>,<y>` (brew 導入済み) で Simulator ウィンドウ座標を直接クリックすれば in-app の tap を自動化できる** (osascript の System Events click は -25204 で不可)。座標は `osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of front window'` からデバイス座標比で換算する (#54 で START tap を実証。cliclick drag による #109 のスクロールは未検証)。通知バナーの実測撮影は配送後約 10 秒で消えるため fire 時刻 +2 秒に照準した background sleep → screenshot で行う。アプリ復帰直後のスクショは遷移アニメ中の旧フレームを掴む (今日カウントの誤読を #54 で実測) — 数秒後の 2 枚目で確定判定する。アニメの静止/再生判定は 1〜2 秒間隔のスクショ複数枚の md5 比較で行い、必ず「静止=全一致」と「再生=不一致」の両方向を実証する (#62 で Reduce Motion 静止化を実証。片方向だけでは検出手法自体の故障と区別できない)。
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
42. レイアウト変更後のスクショで「既存デザインか回帰か」に迷ったら、`docs/ver1_2/screen/` の旧ストア掲載スクショ (6.7インチ/iPad 別) と突き合わせて判定する (#64 で実証。ユーザー確認を挟まず即断できる)。

各ルールの事故経緯・実測データ・Issue 番号付きの詳細は `docs/claude-lessons-archive.md` を参照。
