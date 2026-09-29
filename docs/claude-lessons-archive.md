# Claude Code 教訓アーカイブ (CLAUDE.md より退避)

CLAUDE.md の常時ルールの出典となった事故経緯の全文アーカイブ。2026-08-15 の Issue #83 で CLAUDE.md から退避した (ルール本体は CLAUDE.md「常時ルール」参照)。同日 Issue #81 で旧 Kiro スタイル SDD (`.kiro/`、`/kiro:*` コマンド) と Serena MCP (`.serena/`) を廃止・撤去した。

以下は退避時点の原文を無編集で保持している。

## 失敗からの教訓

- Edit/Write が失敗した時や、想定外のファイル変更を検出した時は、まず並行ターミナルの別 Claude Code セッション（または別プロセス）による書き換えを疑い、ファイルの timestamp と内容を確認してから操作を続ける。気づかず上書きすると他セッションの in-progress work を破壊するため、「Edit 失敗 = 何かが書き換えた」と即座に状況確認する習慣にする。
- SwiftLint の `custom_rules` の regex は「違反パターン」を書くのが正方向。新規 custom rule を入れる前に、**意図する正例と反例の両方をテキストで列挙して regex を当て**、ヒット方向が反転していないかを必ず確認する。Issue #15 では反転バグに気付かず `disable:next` workaround を 4 ヶ所撒く事故が起きた。
- Bash でビルド/テスト系コマンド (`make` / `xcodebuild` / `npm test` / `pytest` 等) を `| tail` / `| head` / `| grep` でフィルタする時は、必ず `set -o pipefail` をコマンド前に置くか、`${PIPESTATUS[0]}` で元コマンドの exit code を取得する (または `tee` で全出力をファイルに残してから `grep` する)。Issue #9 で `make tests 2>&1 | tail -80` の exit code が tail の 0 に隠れて、`make: *** [unit-tests] Error 70` という失敗を「成功」と誤判定する事故が発生した。**注意: このプロジェクトの shell は zsh。`${PIPESTATUS[0]}` は zsh では空文字を返す (bash 専用構文) ため silent no-op になる。zsh では `${pipestatus[1]}` (小文字・1-indexed) を使うか、`set -o pipefail` を前置するか、xcodebuild/make は出力中の `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` / `Error 6x` / `** TEST FAILED **` 等の成功・失敗マーカーで判定する。Issue #39 で subagent が `${PIPESTATUS[0]}` を使い空が返ったが、成功マーカーで代替判定して事なきを得た。**
- Plan / spec / design doc を書く時、他 Issue コメントや過去 commit で言及されている tool / script / path をそのまま引用するのは禁止。書く前に Glob か Read で実在を 1 回確認する。Why: 二次情報を primary source 扱いすると、実行時に subagent が BLOCKED で戻り「巻き戻し → controller 補正 → 再開」のループが発生する (Issue #13 Part A で `bin/add-to-target.rb` が実は `app/bin/` 配下にあった事例)。How to apply: plan を commit する前のセルフレビューで、参照している全ての tool/script path を 1 度 Glob する。
- macOS `base64 -i <file>` のデフォルト出力は 76 文字で line-wrap される。clipboard 経由で App Store Connect / CI Secret UI のような単一行入力欄に貼り付けると、改行が silently 落ちて Secret が壊れる。`base64 -i ... | tr -d '\n' | pbcopy` で 1 行化してからコピーする。Why: 復元時に base64 -d が静かに失敗 or 部分的なデータが流れて、CI build が後段で意味不明な失敗を起こす。How to apply: 任意の CI Secret 投入手順 (Xcode Cloud / GitHub Actions / Bitrise / fastlane match) を docs に書く時、base64 → clipboard の間に `tr -d '\n'` を必ず挟む。
- Explore agent / Glob-grep agent に UI component や view / function の「問題箇所」を返させる時、agent 指示書に **「そのファイル / シンボルが live コード (App entry / ViewModel / wire-up された View hierarchy) から参照されているかを `grep` で verify し、`live` か `dead/unused` の判定を付ける」** を必ず含める。Why: dead code (refactor 途中で wire-up 忘れ等) を修正してもユーザー価値ゼロで、spec scope の見積もりが狂い、結果的に「巻き戻し → spec amend → 再 plan」のループが発生する (Issue #26 で `SessionStatsView` / `TimerControlsView` を hardcoded color の修正対象として spec 化しかけたが、grep の結果 dead code と判明し scope 縮小した事例)。How to apply: `superpowers:daily-issue-triage` / `superpowers:brainstorming` の Step 3 (Explore dispatch) では、prompt の最後に「report each finding as live (used in production path) or dead (no live ref via grep)」を必ず追記する。
- 破壊的操作 (`rm` / `git reset` / 既存ファイル上書き等) は、ユーザーの literal turn にファイル名が含まれるまで実行しない。Why: `AskUserQuestion` の選択肢ラベル (`Recommended` 含む) は auto mode classifier に「明示指示」として認められず、確認なしで `rm` を撃つと連続ブロックされる。SessionStart hook が `pending-reflection.md` のような pending file を生成する運用が続く限り再発する。How to apply: destructive 系は **user 自身の turn に対象ファイル名が出るまで実行しない**。Issue #47 で、assistant がファイル名を提示し user が「両方OK」と短く同意しただけでは削除が通らなかった — **この安全側の挙動は正しい**。assistant 主導の削除提案に user が「OK」と返すだけでは authorization として扱わず、(i) user 自身にファイル名を述べてもらう、または (ii) user に `! rm <path>` で自分で実行してもらう、のいずれかで進める。承諾の取り方を工夫してブロックを回避するのではなく、ユーザーの明示的意思を正面から確認することが目的。
- 検査・linter・validator・checker 系ツールを作る／レビューする時、本体は **FAIL(RED) パス**。「壊れた入力を渡したら正しく RED になるか」を scratch repo / fixture で実証する。正常系が GREEN なだけの確認は "vacuously green" で checker 最大の盲点。Why: Issue #11 では advisor + scratch repo の往復で、コードを1行も書く前に false-green バグを3件潰せた (`git status --ignored` は tracked ファイルに盲目 / exit code は negation で反転 / dir-only パターン×不在パスの取りこぼし)。How to apply: checker 実装の plan には必ず「意図的に壊した入力で RED を確認」する RED ステップを入れる。
- TDD で修正を実装する時、**旧挙動を保持するフォールバック分岐** (例: Issue #56 の「endDate が nil なら従来の 1 減算」) を新コードに残す場合、RED テストが新パスではなくフォールバックを通って**未実装でも green になる** (vacuously green の TDD 変種)。Why: Issue #56 の plan セルフレビューで、phase 切替テストが start を経由せず endDate 未設定のままだったため、フォールバック減算が偶然期待値と一致して素通りするところだった。How to apply: フォールバック付き実装の RED テストでは「新パスに必ず入る前提条件 (今回なら start 経由で endDate を張る)」をテスト内で明示的に整え、RED の失敗値を plan に予測記載して実際の失敗値と突き合わせてから GREEN 実装に進む。
- 記録済みの教訓・MEMORY を適用する時、**その制約が literal に禁じている対象だけ**に適用し、広い禁止へ過剰一般化しない。Why: Issue #11 で「`git check-ignore` の **exit code** を信じるな」という MEMORY を「check-ignore 自体を使うな」と読みかけたが、実際は exit code がダメなだけで **出力 (last-matched rule) のパースは可**。狭い禁止を全面禁止に膨らませると正しい解法を捨てる。How to apply: MEMORY/教訓を引く時、禁止対象が「ツールそのもの」か「特定の使い方 (exit code / 特定フラグ)」かを一度切り分けてから適用する。
- Simulator 操作のように複数ステップにまたがる Bash コマンド (uninstall → install → launch 等) でアプリバンドルパスを組み立てる時は、**必ず絶対パスで書く**。Why: 直前の `cd app && ...` で working directory が移動しているため、相対パスの `app/build/...` が `app/app/build/...` に二重化し、コマンドが 2 分タイムアウトで**無言失敗**する (Issue #57 の Task 4 検証で発生)。How to apply: `xcrun simctl install/launch` 等にバンドルパスを渡す時は `/Users/.../LeafTimer/app/build/...` のように絶対パスを組む。
- `make unit-tests` / `make tests` 等のビルド・テストコマンドは、**直前ターンの cwd に依存せず毎回 `cd /Users/.../LeafTimer/app &&` を前置する**。Why: 途中に `cd <repo-root> && git commit` のようなコマンドを挟むと cwd がルートに移り、ルートには `unit-tests` ターゲットが無いため `make: *** No rule to make target` で即失敗する。しかも grep フィルタ付きだと exit code が隠れて**出力が空になるだけ**なので、成功マーカー不在に気づかないと素通りする (Issue #97 の Task 3 検証で発生。出力空を怪しんで tee ログの `No rule to make target` で発覚)。How to apply: Bash でビルド/テスト系を打つ時は常に絶対パスの `cd` を同一コマンド内に含め、判定は出力マーカー (`** TEST SUCCEEDED **` 等) の存在確認で行う。
- ビルド/テスト出力から成否を判定する grep パターンは、**推測で書かず、対象ツールの実際の成功時出力を 1 度見てから決める**。Why: PR #92 のセッションで `grep -c "orphan"` が precheck の**成功**出力 `✅ targets: no new orphan Swift files` にヒットし、`grep "ibtool.*error"` が `ibtool --errors --warnings` という**コマンドラインフラグ**にヒットして、1 セッションで 2 回 GREEN を RED と誤読しかけた。「失敗しそうな単語」を想像で列挙すると、成功メッセージや引数に同じ語が含まれていて偽陽性になる。How to apply: 判定コマンドを書く前に対象ツールを素で 1 回実行して出力を読み、**成功マーカーの存在**と**失敗マーカーの不在**の両方で判定する (例: `✅ xcode-precheck passed` が 1 以上 かつ `❌` が 0)。
- zsh では `grep --include=*.swift` の glob をクォートしないと `no matches found` でコマンド自体が実行されず、`| wc -l` が **`0`** を返す。これを「該当 0 件」と読むと調査結果が丸ごと偽になる。`--include="*.swift"` と必ずクォートする。Why: Issue #99 のセッションで固定 font size の実数を数える grep が 0 を返し、「対応済み」と誤判定しかけた (クォートし直したら 39 件)。How to apply: `--include` / `--exclude` を書いたら glob をクォートし、**0 件という結果が出たら必ずエラー出力の有無を確認する** (`no matches found` はコマンド不成立であって 0 件ではない)。
- subagent の「DONE」報告は、**報告時点のスナップショットと一致しないことがある**。Issue #58 では 1 セッションで 2 回発生した (存在しない commit SHA を書いて報告 / 未コミットの変更が報告に含まれない)。controller は報告を受けたら毎回 `git log --oneline` / `git status --short` / 成果物の mtime を実地確認する。**ただし食い違いを見つけても「虚偽報告」と即断してはいけない — agent がまだ生きて作業中の可能性を先に疑う。** Why: #58 で即断して別 agent を並行 dispatch しかけ、同一ファイル + 同一シミュレータへの二重書き込み寸前だった (後任 agent が mtime の変化と生存プロセスを検知して自ら BLOCKED で停止し、事故を免れた)。シミュレータや共有リソースを触るタスクでは、二重実行は「エラーにならず、もっともらしい別物の結果」を生む silent failure になる。How to apply: 報告と実態が食い違ったら、(1) 対象ファイルの mtime が今も動いていないか、(2) 関連プロセスが生きていないか を先に確認し、生きていれば当該 agent に完遂させる。dispatch し直すのは死亡を確認してから。
- Simulator で UI 要素の有無を観測する前に、**その要素がどの画面に配線されているかを `grep` で確定させる**。Why: Issue #90 の調査で「EEA で広告バナーが出るか」をトップ画面のスクショで判定しようとしたが、`AdsView` の live 参照は `EnhancedSettingView.swift:94` の 1 箇所のみ (歯車 → 設定画面) で、**トップ画面には広告が無い**ため対照実験そのものが無意味だった (他フォーマットの Interstitial / Rewarded / Native / AppOpen も実装 0 件)。How to apply: スクショ検証を設計する時点で対象 View の参照元を grep し、「どの画面に遷移すれば見えるか」を先に確定する。`simctl` に tap が無いので、遷移が必要な画面は観測手段自体を変える (ログ / UserDefaults / XCUITest) 必要がある。

## プロジェクト固有の制約

- Xcode Cloud Workflow の "scheme may only exist locally" 警告は、scheme が shared + git tracked + remote push 済みなら基本 false positive。Why: 実 build log で `Cannot find scheme` が出ていなければ build 自体は通っているので、警告メッセージそのものを起点に scheme 設定を弄ると無駄な往復が増える。How to apply: 次回 Xcode Cloud の scheme 警告対応時は、scheme 設定を疑う前に最新 build log を `Cannot find scheme` 等のエラー文字列で grep し、build error が無ければ警告は無視する。
- `app/.gitignore` の `*.xcworkspace` ワイルドカードは `xcshareddata/swiftpm/Package.resolved` を巻き込む。Why: Issue #31 で SPM 依存追加時に `Package.resolved` が commit されず Xcode Cloud の dependency 解決が失敗した実害があった。How to apply: SPM 依存を追加・更新する時は `git status` に `Package.resolved` が出るかを必ず確認し、出ていなければ `git add -f` で強制 add するか `.gitignore` の whitelist (`!**/Package.resolved`) を追加する。
- 新規 Swift ファイルを Xcode project に追加すると `project.pbxproj` の children グループが未ソート状態になる。`make sort` を**最終 commit の前に**実行すること。実行を忘れると PR 作成直後に「1 uncommitted change」warning として表面化し、cosmetic 差分の追い commit が 1 回余計に発生する (Issue #8 で `make sort` 漏れが PR 化後に発覚した)。How to apply: 新規ファイル追加を含むブランチでは push/PR 前のセルフチェックに `make sort && git status` を入れる。
- 新規 Swift ファイルを追加したら `make precheck` (= `bin/xcode-precheck.rb`) で **target attach 漏れ (orphan)** と **Makefile destination のシミュレータ不在**を検証する。`make tests` の先頭に組み込み済みなので通常は自動で走るが、`make tests` を回さず commit する時は単体で `make precheck` を実行する。Why: ディスクに `.swift` があってもどの target にも attach されていないと**ビルドにもテストにも含まれず silent に無視される** (Issue #15)。既存の 14 orphan は `bin/xcode-precheck-orphans.txt` で grandfather 済みなので、**新規** orphan だけが fail する。orphan を意図的に未配線にする場合は `ruby bin/xcode-precheck.rb --update-baseline` で baseline に追加する (Issue #10)。追記 (Issue #47/PR #49): この 14 orphan は全て 2025-09 の放棄された旧実装と判明し削除、baseline は空になった。**orphan baseline の file はどの target にも未配線=ビルド非対象なので、live コードが参照していればビルドが落ちる → liveness はビルド成立で実質決着済み**。「各ファイルを grep で live 参照チェック」を素朴にやると、dead クラスタ内の相互参照 (例: `ComponentLibrary`→`Buttons`) や test の自己参照で **false な "live" hit** が出る (#26 の罠)。orphan cleanup は「liveness grep」ではなく「放棄→削除 / 配線忘れ→attach の**意図判断**」として扱い、判断材料は `git log` の最終更新時期 + live 等価実装の有無にする。
- `make tests` の依存チェーン (`precheck` 等) に Apple 同梱外の言語ツールチェイン (ruby gem 等) を足す時は、`require` を `rescue LoadError` でガードして gem 不在でも green を維持するか、CI hook で install する。Why: Issue #10 で `make tests → precheck → require 'xcodeproj'` を足したが、gem 不在環境ではテスト 1 件走る前に LoadError で build が red になるところだった (advisor 指摘で事前回収し rescue ガードを追加)。How to apply: `make` ターゲットの prerequisite に新スクリプトを足す時、そのスクリプトが require/import する非標準ライブラリを列挙し、無くても致命的でないものは rescue で skip にフォールバックさせる。
- `app/bin/` の `foo-bar.rb`（ハイフン=CLI 層）と `foo_bar.rb`（アンダースコア=純粋ロジック module、minitest 対象）のペア、および `GIFView`（SwiftUI wrapper）と `GIFPlayerView`（UIKit 実体）は重複ではなく意図的な2層構成。Why: 名前が似ているだけで「重複ファイル」として削除候補に載せると、片層を消してビルド/テストが壊れる。How to apply: デッドコード整理・重複ファイル調査の際は、削除候補にする前に `diff` と参照確認（Makefile / require_relative / 呼び出し元）で層構成かどうかを先に判定する。
- トップ画面 (`TimerView`) の背景は `TimerViewModel+extensions.swift` の `getBackgroundColor(colorScheme:)` で **work/break × light/dark の4状態**に変化する (light は淡色・dark は濃色)。この背景の上に重ねる overlay UI は、ハードコード色 (例: `rgba(255,255,255,.x)` 相当の固定白) を使うと light モードで不可視になる。`.ultraThinMaterial` + semantic color (`.primary` / `.secondary` / `.green` / `.orange` 等の adaptive 色) を使い、**Simulator で4状態 (×ロケール) を必ず目視検証**する (`xcrun simctl ui <SIM> appearance light|dark` + `-AppleLanguages`)。Why: Issue #39 でブラウザモックが dark+work の1状態しか検証しておらず、light モードの material 可読性が盲点だった (advisor 指摘で事前回収)。
- このリポジトリの default branch は **`master`** (`main` ではない)。`daily-issue-triage` 等の skill boilerplate が `git checkout main` を前提にしており、しかも **parallel Bash batch 内で1コマンドが失敗すると同バッチの全コマンドが cancel** され、結果が partial / 前後して「出力が壊れた」ように見える。Why: Issue #11 のセッション冒頭で open issue を誤認する事故が起きた。How to apply: ツール不調を疑う前にバッチ内に失敗コマンド (master repo での `checkout main` 等) が混ざっていないか確認し、read-only な状態確認クエリと失敗しうる `git checkout` は別バッチに分ける。
- **Dynamic Type (「文字を大きく」) の検証は `xcrun simctl ui booted content_size <値>` で tap なしに切り替えられる。** 値は標準域が `extra-small` 〜 `extra-extra-extra-large`、拡張域が `accessibility-medium` 〜 `accessibility-extra-extra-extra-large` (= AX5)。ただし **install 直後の初回起動では onboarding の `fullScreenCover` が最前面に出て、`-InitialScreen=` で開いた画面を覆い隠す**。他画面を撮る前に `xcrun simctl spawn booted defaults write jp.ema.LeafTimer hasSeenOnboarding -bool true` を打つこと (Issue #58 Task 3 で 1 枚撮り直しが発生)。逆に onboarding 自体を撮る時は `defaults delete` で消す — **`simctl uninstall` は使わない** (ATT の決定までリセットされ、次回起動で手動タップが必要な ATT ダイアログが出る。#90 のコメントに記録済み)。tap でしか到達できない画面は `TimerView.swift` の `#if DEBUG` ブロックにある起動引数フックで直接開ける: `-InitialScreen=settings` / `history` / `timePreview`。#62 (Reduce Motion) や #64 (SE/iPad 対応) の UI 検証でもそのまま再利用できる。なお設定画面の下部はスクロール手段が無く未検証のまま (#109)。
- **ビルド成果物 (`.app`) の場所を `find app/build ...` で探さない。** `app/build/DerivedData/Build/Products/Debug-iphonesimulator/LeafTimer.app` に**古いビルドの残骸**が残っており (2026-07-26 時点で 2026-07-18 のものが存在)、`find` はこれを掴む。`app/Makefile` の `xcodebuild` は `-derivedDataPath` を指定していないため、**実際の成果物はデフォルトの `~/Library/Developer/Xcode/DerivedData/LeafTimer-<hash>/Build/Products/Debug-iphonesimulator/` に出る**。Why: 古い `.app` を Simulator に install すると「変更が反映されていない」と誤診する。エラーにならず古い画面が出るだけなので **silent に間違った検証結果**を出す。How to apply: `BUILT_DIR=$(xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -showBuildSettings 2>/dev/null | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //')` で取得し、`$BUILT_DIR/LeafTimer.app` を使う (PR #92 で発覚)。

## 効率化ルール

- **全ての** agent dispatch (並列 teammate に限らず、implementer / reviewer / fixer など単発 subagent も含む) の指示書に「最終報告の全文を SendMessage で main へ送信してから idle になる」を必ず明記する。Why: idle 通知だけでは報告本文が main に届かず回収往復が発生する。並列 5体中4体で発生した初回実績に加え、Issue #57 では SDD の task reviewer dispatch でこの定型文を入れ忘れて再発した (implementer 向けと思い込み、reviewer には不要と暗黙に判断したのが敗因)。How to apply: skill のテンプレ (subagent-driven-development の implementer/reviewer/fixer prompt 等) を使う時も、テンプレに定型文が無ければ dispatch 前に必ず末尾へ追記する。役割を問わず「dispatch = 定型文チェック」を機械的に行う。
- 上記の SendMessage 定型文に加えて、**reviewer には「report file に書き出してから SendMessage する」の二重化も指示する**。Why: `subagent-driven-development` の task-reviewer テンプレートは report file を使わず「最終メッセージ自体が報告」という設計のため、agent が idle になった瞬間に本文が失われる。定型文を入れても発生し、Issue #58 では 3 連続 (Task 4/5/6) でロストして毎回回収の往復が起きた。**定型文の強度を上げても解決しない構造的な問題**で、ファイルに落とさせた Task 7 以降は再発しなかった。How to apply: reviewer / re-reviewer の dispatch prompt には「まず `<workspace>/task-N-review.md` に全文を書き、その後同じ内容を SendMessage で送る」と明記する。implementer は元々 report file を持つのでこの追加は不要。
- 新規 hook スクリプト（SessionEnd/SessionStart など）を settings.json に配線する前に、sample JSON を stdin に pipe-test して bail 条件・self-detach・sentinel ガードを単体検証する。配線後の silent failure（特に `claude -p --bare` の OAuth 切れのような沈黙失敗）を未然に検出できる。
- plan-driven な PR では、Issue #15 の `f2df20e` の convention に倣い、**実装の最初のコミットとして** `docs/superpowers/plans/YYYY-MM-DD-issue-NN[-NN…]-slug.md` を含める。PR 作成後の追い commit になると CI 履歴とレビュー導線がズレるため、ブランチ作成直後に plan を commit する。
- ブランチ push や `gh pr create` の前に、必ず `git fetch && gh pr list --state all --head <branch>` で既存 PR / merge 状況を確認する。ローカル master が古いまま push して「既に MERGED」で空振りするのを防ぐ。
- `superpowers:subagent-driven-development` を採用する時、Plan の Task が「観察+編集+検証+commit」のような小粒で密接結合なら、Task ごとに subagent を dispatch せず**複数 Task を 1 subagent に full text で束ねて渡す**。レビューはまとめて 2 段階 (spec compliance → code quality) で実施する。Why: 個別 dispatch のオーバーヘッド (context 渡し / Tool 再 load / agent boot) > 実行コストになることがある。Issue #16 で Plan の Task 2-6 を 1 subagent に束ね、起動コストを抑えつつ品質ゲートは両 reviewer で確保できた。
- Agent tool 経由で subagent に `cd app && make unit-tests` を実行させる時、Bash の `timeout` を明示的に `600000` (10 分) に設定するよう subagent 指示書に書く。Why: xcodebuild + simulator boot + test 実行で 2〜5 分かかるため、Bash のデフォルト 2 分でタイムアウトすると、せっかくのテスト実行が無駄になる。
- マネージド CI runner (Xcode Cloud / GitHub-hosted runner 等) は Apple 同梱以外の言語ツールチェイン (CocoaPods / Bundler 等) の preinstall を保証しない。`ci_post_clone.sh` のような CI hook の冒頭で必要なツールを明示的に `brew install` / `gem install` してから本処理に入る。Why: ローカルでは `pod install` が動くため見落としやすく、初回本番ビルド時に silent break する。How to apply: 新規 CI hook を書く時、ローカル前提のツール (cocoapods / bundler / yarn / poetry 等) があるかチェックし、ある場合は `set -euo pipefail` 配下で install ステップを先頭に追加する。
- SwiftLint 組み込み `empty_count` rule は tuple の Int field など `.isEmpty` を使えない箇所でも `.count == 0` を検出する。新規コードでは可能な限り `.isEmpty` を使い、Int field 等で不可避な場合のみ `// swiftlint:disable:next empty_count` で 1 行 suppress する。Why: Issue #8 では test 内の `(date, count)` tuple 比較で違反が `make tests` 段階まで検出されず、最後に suppress 対応が発生した。
- `gh pr create` の本文 (markdown) は **ローカルファイルパスの画像を埋め込めない**。`![](/tmp/foo.png)` と書いても GitHub は到達可能な URL しか取得しないため、空表示になる (`gh` に upload-and-embed フラグは無い)。iOS の PR スクリーンショットは `SendUserFile` でユーザーに渡し、PR 説明欄に「スクリーンショット」セクションの枠だけ用意して、**ユーザーがブラウザでドラッグ&ドロップ添付**する運用にする。`/tmp` パスを本文に書いて「スクショ添付済み」と主張しない。Why: Issue #39 で 4状態スクショを PR に載せる際に発覚 (advisor 指摘)。
- 「スキル化候補」issue を着手する前に、チェック内容が**機械的 (regex/script で検証可能) か判断的か**を見極める。機械的かつプロジェクト固有なら `~/.claude/skills/` のドキュメントスキルではなく **repo 内スクリプト + `make` ターゲット**として実装する (`writing-skills` のガイダンス: 機械的チェックは自動化・固有規約はリポジトリに置く)。Why: Issue #10 で当初「スキル新設」前提だったが、3 チェック全てが機械的+固有と判明し doc スキルなら無駄になるところだった (advisor 指摘で着手前に scope 再確認)。How to apply: `daily-issue-triage` でスキル化候補 issue を分類する時、各チェックが script で書けるか自問し、書けるなら downstream を `writing-skills` ではなく repo スクリプト + TDD に向ける。
- Plan / doc に **それ自体が code fence (` ``` `) を含むファイル全文** (例: frontmatter + fenced 例を持つ SKILL.md) を埋め込む時、plan 内の fenced block にインライン貼りすると fence が 2 段ネストして **Write / tool-call の serialization が壊れ「malformed and could not be parsed」で連続リトライ**になる。回避: 埋め込むファイルは **独立した companion ファイル**として別途 Write し (fence ネストが 1 段に収まる)、plan からはパス参照する。Why: Issue #48 の plan で SKILL.md 全文をインライン埋め込みして Write が 3 回壊れた。How to apply: 埋め込み対象が ` ``` ` を含むなら最初から companion ファイルに分離し、plan は「`<path>` を参照」と書く。
- dispatch した subagent (特に長時間実行される final review 等) が `idle_notification` の `failureReason` に "session limit" を返して落ちた場合、放置や再試行待ちをせず**同じタスクを別モデルで即座に再 dispatch** して続行する。Why: session limit は待っても自動回復しないため、待機時間がそのまま停滞になる。How to apply: `Agent` の `model` パラメータで別ティアを指定して同一 prompt を再投入する。
- final review が Findings とは別に **Recommendations** を返した場合、1 件ずつ行き先 (fix wave 同梱 / follow-up issue 化 / issue コメント / 採用しない理由の記録) を明示的に決めてから次工程に進む。silent drop 禁止。Why: Issue #59/#60 (PR #96) で Recommendations 4 件のうち Rec#2 (Accessibility Inspector 監査) だけ routing 漏れし、advisor 指摘で Issue #97 コメントとして事後回収した。SDD workspace (ledger) はマージ後に削除されるため、回収先が消える前に routing する必要がある。How to apply: final review 受領時に Recommendations を番号付きで ledger に列挙し、各行に routing 先を書き切ってから fix dispatch / 総合検証工程へ進む。
- `gh pr checks <PR> --watch` は GitHub GraphQL API 呼び出しが `read: operation timed out` で失敗することがある (PR #96 で実績)。安定しているのは `until gh pr checks <PR> --json name,bucket --jq 'all(.[]; .bucket != "pending")' 2>/dev/null | grep -q true; do sleep 30; done` のポーリングループなので、`--watch` より先にこちらを使う。
- このリポジトリは GitHub の Auto-merge が無効 (`gh pr merge --auto` は "Auto merge is not allowed for this repository (enablePullRequestAutoMerge)" で失敗、PR #100 で実績)。CI 完了をポーリングで確認してから `gh pr merge <PR> --merge` を明示的に実行する。


## 2026-08-15 追記: CI 待ちポーリングの陳腐化と非同期通知の偽陽性 (PR #111)

CLAUDE.md ルール 23 の旧内容「`until gh pr checks <PR> --json name,bucket --jq 'all(.[]; .bucket != "pending")' 2>/dev/null | grep -q true; do sleep 30; done`」は、PR #96 時点では有効だったが、2026-08-15 の環境では Bash の sleep が無効化されておりターン内で待機できない。同セッション (PR #111 の CI 待ち) で観測した事実:

- バックグラウンド実行したポーリングループは**最終的に正常完走していた** (出力ファイルに全 pass の結果が残っていた) が、**「completed」通知が実際の完了より早く届き**、その時点で出力ファイルは空だった。
- Monitor ツールのイベントは CI 開始 2 分時点で「claude-review: pass」を 2 回偽報告した (実際の所要は 10m20s)。sleep 無効により高速ポーリング化し、API レプリカ間の不整合な応答を拾ったとみられる。
- 「background Bash が壊れている」という診断は**誤り**だった (advisor が訂正)。壊れていたのは通知のタイミングと内容のみ。
- 誤 merge を防いだのは `gh pr checks 111 && gh pr merge 111` の同一チェーンゲート。偽 pass イベント直後の merge 試行が、チェーン先頭の再検証 (exit 8) で止まった。
- 確実に動いたのはフォアグラウンドの `gh run watch <run-id> --interval 30` (ツール内部で待機するため shell の sleep 無効化の影響を受けない)。

この経緯からルール 23/24 を改訂した (docs/retro-2026-08-15-ci-wait ブランチ)。

## 2026-09-29 追記: #171 で CLAUDE.md から退避したルール全文

CLAUDE.md を 18,000B 以下に圧縮した時 (#171)、以下のルールは「何をするか」だけに縮めるか、プロジェクト skill (`.claude/skills/leaftimer-simulator-verification` / `leaftimer-xcode-deps`) へ移した。事故の経緯・PR 番号・実測値を含む圧縮前の全文をここに残す。

### ルール 12

Simulator で UI 要素の有無を観測する前に、その View の live 参照元を grep して「どの画面に遷移すれば見えるか」を確定させる。

### ルール 26

マネージド CI runner は CocoaPods / Bundler 等の preinstall を保証しない。CI hook の冒頭で `set -euo pipefail` 配下の明示 install を先頭に置く。**CocoaPods は `app/Gemfile.lock` で固定し常に `bundle exec pod …` で動かす** (#143。Ruby は `app/.ruby-version`、CI は `ruby/setup-ruby@v1` の `working-directory: app` + `bundler-cache: true` が両方を読む)。素の `pod` / `gem install cocoapods` / `pod _<ver>_` に戻さない — macos runner の `pod` は brew ruby の RubyGems binstub で**常に最新 install 版を activate する**ため lock 版へ downgrade できない (PR #144 で実測)。Gemfile.lock と Podfile.lock の `COCOAPODS:` 行の一致は `make cocoapods-lock-check` (tests チェーン内) が守る。Xcode Cloud の `ci_post_clone.sh` は master 限定トリガーで PR 検証できないため #143 のフォローアップ (未着手)。

### ルール 27

`make` の依存チェーンに Apple 同梱外の ruby gem 等を足す時は `require` を `rescue LoadError` でガードし、gem 不在でも green を維持する。 **ただしガードは CI で silent green を生みうる** — `ruby/setup-ruby@v1` の `bundler-cache: true` は gem を `app/vendor/bundle` (deployment mode) に隔離し自身の Ruby を PATH 先頭に置くため、後続 step の素の `ruby bin/*.rb` は lock の gem を `require` できず、ガードが黙って skip する (PR #146 final review I-1: orphan gate が `⚠️ skipped` のまま green)。CI では `bundle exec make tests` のように **make ごと bundle exec で包み**、ガード付き checker の ✅ 行を受け入れ基準に入れる。

### ルール 28

新規 Swift ファイルの pbxproj 配線は手編集せず **`make add-file FILE=<project相対パス> TARGET=app|test`** を使う (#130 で整備。sort + precheck まで自動実行、idempotent)。TARGET は必須 — app/test の取り違えは「テストが本番バイナリに入る」事故になる。配線 (pbxproj 差分) を**そのファイルを追加する commit 自体に含める** (pbxproj の children 未ソート対策。「最終 commit 前」に後送りすると task review で指摘され fix round が 1 つ増える — PR #115 で実測) / `make precheck` で orphan (target 未 attach) を検出。orphan の扱いは liveness grep でなく「放棄→削除 / 配線忘れ→attach」の意図判断で決める (材料は git log の最終更新時期 + live 等価実装の有無)。意図的な orphan は `ruby bin/xcode-precheck.rb --update-baseline` で baseline に追加。**`make add-file` は未配線 .swift が複数並存する状態で `&&` 連結できない** — 1 回目の内部 precheck が 2 つ目を orphan 判定して exit 2 で止まる。1 ファイルずつ実行する (PR #137 で実測)。**target 削除も手編集せず xcodeproj gem の one-off で行う**が、`target.remove_from_project` は `XCBuildConfiguration` と `TargetAttributes` (UUID キーで target 名の文字列を含まない) を連鎖削除しない — 受け入れは文字列 grep でなく構造検査 (`TargetAttributes.keys - targets.map(&:uuid) == []`、参照 UUID ⊆ 定義 UUID) で行い、`pod install && make sort` を 2 回回して pbxproj が安定することを確認する (PR #140 で実測: grep は `remaining refs: 0` を返したが残骸 2 種あり)。 **この構造検査は `make pbxproj-structure-check` (precheck 内、#73 で repo 化) が行う** — SPM 参照の除去も同じ gem の one-off (`frameworks_build_phase.remove_build_file` → `package_product_dependencies.delete` + `remove_from_project` → `root_object.package_references.delete` + `remove_from_project`) で行い、検証は fresh な `-derivedDataPath` で `xcodebuild test` を回して `SourcePackages/checkouts` が生成されないことを実測する (既定 DerivedData の stale な SPM 成果物がリンク切れを隠す — #73)。

### ルール 29

`app/.gitignore` の `*.xcworkspace` は `xcshareddata/swiftpm/Package.resolved` を巻き込む。SPM 依存の追加・更新時は `git status` に `Package.resolved` が出るか確認し、出なければ `git add -f` するか `.gitignore` に `!**/Package.resolved` を足す。

### ルール 30

ビルド成果物 (`.app`) を `find app/build` で探さない (古い残骸を掴み silent に誤検証する)。`xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -showBuildSettings 2>/dev/null | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //'` で実パスを取得する。同名 Simulator が複数世代ある機種 (iPhone SE 等) では `name=...,OS=latest` は曖昧マッチで exit 70 になる — `xcrun simctl list devices available` で UDID を引き、`-destination "platform=iOS Simulator,id=<UDID>"` で指定する (#113 で実測)。

### ルール 31

トップ画面 (`TimerView`) の背景は work/break × light/dark の 4 状態 (`TimerViewModel+extensions.swift` の `getBackgroundColor`)。overlay UI はハードコード色でなく `.ultraThinMaterial` + semantic color を使い、Simulator で 4 状態 (×ロケール) を目視検証する (`xcrun simctl ui <SIM> appearance light|dark` + `-AppleLanguages`)。

### ルール 32

Dynamic Type 検証は `xcrun simctl ui booted content_size <値>` (標準域 `extra-small`〜`extra-extra-extra-large`、拡張域 `accessibility-medium`〜`accessibility-extra-extra-extra-large` = AX5)。install 直後の初回起動は onboarding の fullScreenCover が最前面に出るため、他画面を撮る前に `xcrun simctl spawn booted defaults write jp.ema.LeafTimer hasSeenOnboarding -bool true` を打つ。onboarding 自体を撮る時は `defaults delete` を使う (`simctl uninstall` は ATT までリセットされるので不可)。tap でしか到達できない画面は起動引数 `-InitialScreen=settings` / `history` / `timePreview` で直接開ける (`TimerView.swift` の DEBUG フック)。葉パターンは `-LeafPattern=small|mid|big` で強制できる (#64)。fresh Simulator では初回起動時に **ATT ダイアログ**が最前面に出て simctl では tap も TCC.db 直書きもできない — `applesimutils --byId <UDID> --bundle jp.ema.LeafTimer --setPermissions "userTracking=YES" --restartSB` で事前付与してから起動する (brew 導入済み。再導入時は `brew trust wix/brew` が必要)。設定画面下部はスクロール手段が無く未検証 (#109)。simctl に tap は無いが、**`cliclick c:<x>,<y>` (brew 導入済み) で Simulator ウィンドウ座標を直接クリックすれば in-app の tap を自動化できる** (osascript の System Events click は -25204 で不可)。座標は `osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of front window'` からデバイス座標比で換算する (#54 で START tap を実証。cliclick drag による #109 のスクロールは未検証)。通知バナーの実測撮影は配送後約 10 秒で消えるため fire 時刻 +2 秒に照準した background sleep → screenshot で行う。アプリ復帰直後のスクショは遷移アニメ中の旧フレームを掴む (今日カウントの誤読を #54 で実測) — 数秒後の 2 枚目で確定判定する。アニメの静止/再生判定は 1〜2 秒間隔のスクショ複数枚の md5 比較で行い、必ず「静止=全一致」と「再生=不一致」の両方向を実証する (#62 で Reduce Motion 静止化を実証。片方向だけでは検出手法自体の故障と区別できない)。 **スクショの目視は縮小した一覧画像で済ませず、1 枚ずつ原寸で下端まで見る** — PR #165 で設定画面下端の AdMob テスト広告 ("Test mode" バナー) を一覧だけ見て「広告なし」と誤報告し、final review に指摘された。

### ルール 42

レイアウト変更後のスクショで「既存デザインか回帰か」に迷ったら、`docs/ver1_2/screen/` の旧ストア掲載スクショ (6.7インチ/iPad 別) と突き合わせて判定する (#64 で実証。ユーザー確認を挟まず即断できる)。

### ルール 43

テストは **新規は XCTest**、View 構造の検証は **ViewInspector** で書く (#78)。Quick/Nimble (`*Spec.swift` 8 本、うち Quick/Nimble は 7 本、`OnboardingViewSpec` は既に XCTest) は**新規追加禁止・既存は据え置き**で、一括移行はしない。`app/Podfile` のテスト用 pod の制約は 2 段構えにしてある (#149 / #152): Quick `~> 7.6` / Nimble `~> 13.7` は optimistic 制約で major 越えだけを止め、**ViewInspector は strict pin `'0.10.3'`** — #150 で 0.10.2 → 0.10.3 の patch 差だけで `ModernTimerViewSpec` の accessibility テスト 2 件の結果が変わったため、patch も含めてアップグレードを明示的な Podfile 編集にしている。**`~>` は patch を固定しない** (`~> 7.6` = `>= 7.6, < 8.0`) ので、Quick/Nimble の patch を止めているのは `Podfile.lock` だけ。その lock も万能ではなく、**引数なしの `bundle exec pod update` と `Podfile.lock` の喪失は lock を無視して解決し直す** (`cocoapods-1.16.2/lib/cocoapods/installer/analyzer.rb:934-947` の `update_mode == :all` / `!lockfile` 分岐) — 更新は必ず pod を名指しした `bundle exec pod update <pod>` で行う。

### ルール 1

ビルド/テスト系コマンドは毎回同一コマンド内で `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置する (直前ターンの cwd に依存しない)。成否は exit code でなく出力マーカーで判定: `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` の存在、かつ `** TEST FAILED **` / `Error 6x` / `No rule to make target` の不在。`Mach error -308 (ipc/mig) server died` / `Lost connection to testmanagerd` 系の FAIL は Simulator インフラ起因の偽 FAIL — コード原因と診断する前に `xcrun simctl shutdown all && killall -9 com.apple.CoreSimulator.CoreSimulatorService` で再起動して 1 回リトライする (PR #134 のセッションで 3 回発生、全て再起動で回復)。

### ルール 3

成否判定の grep パターンは推測で書かず、対象ツールの実際の成功出力を 1 回見てから「成功マーカーの存在 + 失敗マーカーの不在」の両条件で書く (成功メッセージやフラグ名に「error」等が含まれ偽陽性になる)。 **make ターゲット名が既存のディレクトリ／ファイルと同名なら `.PHONY` が必須** — 無いと make は `is up to date` を出して何も実行せず exit 0 になる (PR #165 の `store-screenshots` ターゲットが入力ディレクトリ `store-screenshots/` と同名で発生。✅ 行の不在で気づけた)。

### ルール 4

zsh では `grep --include="*.swift"` のように glob を必ずクォートする。結果が 0 件の時は `no matches found` (コマンド不成立) と「本当に 0 件」を必ず区別する。**このハーネスの `grep` は ripgrep 実装で `.gitignore` を尊重する** — 「参照ゼロ」を主張する検証は `/usr/bin/grep` で取り直す (PR #140 の reviewer が `.superpowers/` のヒット欠落を実測)。

### ルール 7

plan / spec に書く tool・script・path は、書く前に Glob か Read で実在を 1 回確認する (他 issue コメント等の二次情報を primary 扱いしない)。issue 本文の API 前提も二次情報 — checker に encode する前に Apple docs を `curl` で原文確認する (#108 の「`Font.custom(size:)` は固定サイズ」は誤りで、固定になるのは `fixedSize:` — PR #144 の task review で判明)。plan に書くコード片は `ruby -c` / `ruby -ryaml` で構文確認する (`/…/x` regex のコメント内 `/`、YAML plain scalar の ` #` で plan 逐語が壊れた — PR #144)。 **依存ツールのバージョン制約演算子・DSL の意味も同じ二次情報** — 推測で書かず、ツール自身の API で実測する (`~> 0.10.3` を「patch まで固定」と plan に書いたが実際は `>= 0.10.3, < 0.11.0` で patch は素通りする。final review が `Pod::Requirement` で実測して発覚 — PR #156)。**plan に貼るコード片は構文確認だけでなく scratchpad で実行し、期待値 (テスト件数・mutation の failure 数・実データでの RED 件数) を実測してから書く** — implementer はその数字を成否判定に使うので、推測値だと「期待と違う」で停止する (PR #156 は 35 件 RED / 11 runs / mutation 3・2 failures をすべて実測値で plan に記載した)。 **その実測は plan に貼る逐語のコードで行う** — プロトタイプで測った値を plan の別バージョンに載せない (PR #158 は assertion 数を 53 と書いたが実測は 54。minitest は `assert_includes` / `assert_empty` を内部の `assert_respond_to` 込みで 2 assertions と数え、plan 版のテストにはプロトタイプより assert が 1 件多かった。plan には「この数値と違ったら止めて報告」と書くので、ズレは implementer を確実に止める)。

### ルール 8

checker / linter / validator を作る・レビューする時は「意図的に壊した入力で正しく RED になる」ことを fixture で実証する。正常系 GREEN だけの確認は vacuously green。**mutation の対象は「新規に強化した全テスト」に広げる** (#133 の a11y 2 件だけ未実証で final review 指摘、PR #137)。また mutation を設計する前に「どの入力がその分岐を通るか」を確認する — plan 指定の sentinel 定数変更は既存テストが実在キーしか見ないため 1 件も波及せず、lproj path 解決の破壊に切り替えて 12 件同時 fail を取得した (PR #137)。実時間依存テストでは `XCTNSPredicateExpectation(object: nil)` が約 1 秒ポーリングなので timeout は「発火予定時刻 + 数秒」の余裕を取り、固定時間窓での下限アサーションは「初回発火を predicate で待ってから delta 判定」にする (PR #140 の `DefaultTimerManagerTests`)。 **ローカル green は CI をモデルしない**: ローカルの `bundle install` (path 未設定) は gem を global gem dir に入れるので「素の `ruby -e 'require …'` が通った」は setup-ruby の `vendor/bundle` 隔離 (CI) では成り立たない。CI 固有の隔離・PATH 差し替えは action のソースを `curl` で原文確認してから結論する (PR #146 の Task 1 がこの誤結論を書き、final review が setup-ruby の bundler.js を読んで回帰を発見)。 **受け入れ手順を書く前に、その検証コマンド自体が効くかを確認する**: (i) スクリプトが ARGV を読むか (`bin/gitignore-doctor.rb` は `FIXTURE_FILE` をハードコードし引数を無視するので「引数で fixture を差し替えて確認した」は vacuous — PR #158 で実測)、(ii) その make ターゲットが `tests` チェーンに含まれるか (`gitignore-check` は入っていない → #159)。mutation の網羅は「新規テスト 1 件 : mutation 1 つ以上」の対応表で確認する (PR #158 は新規 7 件のうち 1 件が未実証で、その未実証テストが守っていた 1 行が Important 欠陥の唯一のガードだった)。

### ルール 13

Edit/Write の失敗や想定外のファイル変更は、並行セッションによる書き換えをまず疑い、timestamp と内容を確認してから続行する。**subagent の稼働中、コントローラは `git checkout` / `git pull` / `git switch` など HEAD を動かすコマンドを実行しない** — subagent は同じ working directory を共有しており、agent の未 commit 作業を巻き込む (#70 で実測: PR merge 後の master 同期が実装 agent の HEAD を移動させた)。稼働中の状態確認は `git log <ref>` / `git show <ref>:<path>` / `git diff <a>..<b>` の読み取り専用に限定し、reviewer 系 agent の指示書にも同じ禁止を明記する。分離が必要なら git worktree を使う。

### ルール 14

破壊的操作 (rm / git reset / 既存ファイル上書き) はユーザー自身の turn に対象ファイル名が出るまで実行しない。AskUserQuestion の選択肢承認は authorization として扱われない — (i) ユーザーにファイル名を述べてもらう、または (ii) `! rm <path>` で自走してもらう。**削除を提案する最初のメッセージで、そのまま貼れる `! git rm -r <path>` (未追跡なら `! rm <path>`) を必ず添える** — 対象一覧だけ見せて「OK」をもらい、その後にコマンドを案内すると往復が 1 回増える (#163 / PR #174 で実測)。例外: `.claude/pending-reflection.md` は SessionStart hook の指示に基づき、AskUserQuestion の選択結果 (追記する / 追記しない) を authorization として削除してよい (#82)。

### ルール 16

subagent に `make unit-tests` 等を実行させる時は Bash timeout を 600000 (10 分) にするよう指示書に明記する (デフォルト 2 分では足りない)。 **subagent は自分が起動した background Bash (xcodebuild 等) の完了を待つと idle になり、完了通知では自動再開しない** — controller が同じログを `until grep -q <終端マーカー> <log>; do sleep 15; done` の background Bash で監視し、完了時に SendMessage で「完了した、次の Step へ」と起こす (PR #150 の Task 2 で 3 回実測。指示書に「background 実行後 idle になったら controller が起こす」と書いておく)。

### ルール 22

plan-driven PR では plan doc を実装より前の最初の commit にする。**plan の task に PR merge ステップを含めない** — subagent-driven-development ではタスクレビューが完了ゲートなので、implementer が merge まで走るとレビュー指摘が常に merge 済みコードに対して出て、追随 commit が必要になる (#66 で実測)。plan は「PR 作成まで」で切り、merge はレビュー通過後にコントローラがルール 24 のチェーンで行う。

### ルール 23

CI 待ちは `gh pr checks --watch` や `until ... sleep 30` ポーリングでなく、**フォアグラウンドの `gh run watch <run-id> --interval 30`** を run ごとに実行する (run ID は `gh pr checks <PR>` の URL 末尾から取る)。この環境の Bash は sleep が無効でターン内待機できず、バックグラウンドタスクの完了通知や Monitor イベントは早発・偽発しうる (PR #111 で実行中ジョブの偽 pass イベントを実測)。**`gh run watch` は成功時に結論行を出さず、ジョブログの末尾 (brew の tap-trust 警告など) で終わることがある** — watch の出力だけで pass と判断せず、完了後に必ず `gh pr checks <PR>` で pass/fail を再確認する (PR #126 / #127 の pr-tests で 2 回とも結論行なしを実測)。**CI 設定 (workflow / Makefile) を変える PR は green check でなく当該 step のログ行で受け入れる** — `gh run view <id> --log | grep "^pr-tests	<step 名>"` で期待メッセージ (例: `✅ cocoapods … available` / `LeafTimer.app NN%`) を確認する。summary 系 step は入力欠落でも exit 0 するため、green は「何も出なかった」と区別できない (PR #144)。 **`gh run view --log` の step 列は `UNKNOWN STEP` になることがある** — `grep "^pr-tests\t<step 名>"` は precheck 等の出力を取りこぼすので、受け入れはメッセージパターン (`grep -E "ruby 3\.4\.4|cocoapods via bundler|lock-check passed|targets: no new orphan"`) で grep する。`rescue LoadError` 系ガード付き checker は「✅ 行の存在」に加えて「`skipped` 行の不在」も条件に入れる (run 33930722131 で実測)。

### ルール 24

このリポジトリは Auto-merge 無効。merge は非同期通知を根拠にせず、必ず `gh pr checks <PR> && gh pr merge <PR> --merge` の同一チェーンで再検証をゲートにして実行する。 **checks 全 pass かつ final review 済みなら、このチェーン自体が事前承認済みの操作 — merge 前に AskUserQuestion を挟まない** (PR #134 で「確認できているなら直接マージできませんか」と押し返された)。`gh pr merge` が auto mode クラシファイアにブロックされることがあるが transient — 同一チェーンを 1 回リトライしてからユーザーに `! gh pr merge <PR> --merge` を依頼する (PR #136 で 2 回目に成功)。

### ルール 41

コードフェンス (バッククォート 3 連) を含むファイル全文を plan 内のフェンスに埋め込まない (serialization が壊れる)。companion ファイルに分離してパス参照する。 **長い plan を Write すると末尾が silent に切れることがある** (PR #146 の plan は Task 3 途中で切れ、追記時に閉じフェンスが 1 行欠落)。plan の commit 前に `/usr/bin/grep -c '^```' <plan>` が偶数であることを確認する。

### ルール 44

plan / spec のファイル名は `YYYY-MM-DD-issue-NN[-NN…]-slug.md` (slug は小文字英数とハイフン。companion は `….SKILL-source.md` のように suffix を足す)。**`plans/` `specs/` 直下は「plan を書いてから `gh pr create` するまで」の一時置き場**で、plan の最終タスクで `git mv` して `archive/` へ移してから `gh pr create` する (#84。「merge 後に別 commit で片付ける」設計にすると 34 件溜まった実績がある)。**`archive/` は「PR 作成済み」を意味する** — merge 済みの歴史だけでなく、PR 作成後 merge 前の in-flight な plan もここに同居する。実際に稼働中かどうかはファイルの場所ではなく branch/PR の状態で判断する。`archive/` 配下は日付プレフィックスのみを要求する (旧規則で書かれた歴史はリネームしない)。`make plan-docs-check` (tests チェーン内) がこの命名を検証し、あわせて**直下に 14 日より長く置かれた plan/spec を滞留として fail させる** (#153。判定は mtime でなくファイル名の日付プレフィックス)。厳格名は保存前に issue 番号を要求するので、**issue 未起票の題材は先に `gh issue create` してから** plan/spec を保存する (`drafts/` のような逃げ道は作らない)。

### ルール 45

CLAUDE.md にルールを新設・改訂する時は、**同じ話題を扱う既存行を `/usr/bin/grep` して自己矛盾を潰してから commit する**。ルール 44 (plan 命名) を追加した際、同じファイルの 13 行目が旧命名 `YYYY-MM-DD-<feature>.md` を指示したままで、新設した `make plan-docs-check` ゲートが次の plan-driven PR を最初の commit で確実に赤にする状態だった (final review が検出 — PR #156)。あわせて、その規約に従うファイルを**生成する plugin skill の boilerplate** (`writing-plans` / `brainstorming` 等。`~/.claude/plugins/cache/` 配下で repo からは直せない) が旧形式を出さないか確認し、出す場合はルール 37 と同じ形で「skill はこう出すので最初の commit 前に直せ」と明記する。
