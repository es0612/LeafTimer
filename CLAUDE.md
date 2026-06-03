# Claude Code Spec-Driven Development

Kiro-style Spec Driven Development implementation using claude code slash commands, hooks and agents.

## Project Context

### Paths
- Steering: `.kiro/steering/`
- Specs: `.kiro/specs/`
- Commands: `.claude/commands/`

### Steering vs Specification

**Steering** (`.kiro/steering/`) - Guide AI with project-wide rules and context
**Specs** (`.kiro/specs/`) - Formalize development process for individual features

### Active Specifications
- Check `.kiro/specs/` for active specifications
- Use `/kiro:spec-status [feature-name]` to check progress

## Development Guidelines
- Think in English, but generate responses in Japanese (思考は英語、回答の生成は日本語で行うように)

## Workflow

### Phase 0: Steering (Optional)
`/kiro:steering` - Create/update steering documents
`/kiro:steering-custom` - Create custom steering for specialized contexts

Note: Optional for new features or small additions. You can proceed directly to spec-init.

### Phase 1: Specification Creation
1. `/kiro:spec-init [detailed description]` - Initialize spec with detailed project description
2. `/kiro:spec-requirements [feature]` - Generate requirements document
3. `/kiro:spec-design [feature]` - Interactive: "Have you reviewed requirements.md? [y/N]"
4. `/kiro:spec-tasks [feature]` - Interactive: Confirms both requirements and design review

### Phase 2: Progress Tracking
`/kiro:spec-status [feature]` - Check current progress and phases

## Development Rules
1. **Consider steering**: Run `/kiro:steering` before major development (optional for new features)
2. **Follow 3-phase approval workflow**: Requirements → Design → Tasks → Implementation
3. **Approval required**: Each phase requires human review (interactive prompt or manual)
4. **No skipping phases**: Design requires approved requirements; Tasks require approved design
5. **Update task status**: Mark tasks as completed when working on them
6. **Keep steering current**: Run `/kiro:steering` after significant changes
7. **Check spec compliance**: Use `/kiro:spec-status` to verify alignment

## Steering Configuration

### Current Steering Files
Managed by `/kiro:steering` command. Updates here reflect command changes.

### Active Steering Files
- `product.md`: Always included - Product context and business objectives
- `tech.md`: Always included - Technology stack and architectural decisions
- `structure.md`: Always included - File organization and code patterns

### Custom Steering Files
<!-- Added by /kiro:steering-custom command -->
<!-- Format:
- `filename.md`: Mode - Pattern(s) - Description
  Mode: Always|Conditional|Manual
  Pattern: File patterns for Conditional mode
-->

### Inclusion Modes
- **Always**: Loaded in every interaction (default)
- **Conditional**: Loaded for specific file patterns (e.g., "*.test.js")
- **Manual**: Reference with `@filename.md` syntax

## 振り返りからの学び

### 失敗からの教訓

- Edit/Write が失敗した時や、想定外のファイル変更を検出した時は、まず並行ターミナルの別 Claude Code セッション（または別プロセス）による書き換えを疑い、ファイルの timestamp と内容を確認してから操作を続ける。気づかず上書きすると他セッションの in-progress work を破壊するため、「Edit 失敗 = 何かが書き換えた」と即座に状況確認する習慣にする。
- SwiftLint の `custom_rules` の regex は「違反パターン」を書くのが正方向。新規 custom rule を入れる前に、**意図する正例と反例の両方をテキストで列挙して regex を当て**、ヒット方向が反転していないかを必ず確認する。Issue #15 では反転バグに気付かず `disable:next` workaround を 4 ヶ所撒く事故が起きた。
- Bash でビルド/テスト系コマンド (`make` / `xcodebuild` / `npm test` / `pytest` 等) を `| tail` / `| head` / `| grep` でフィルタする時は、必ず `set -o pipefail` をコマンド前に置くか、`${PIPESTATUS[0]}` で元コマンドの exit code を取得する (または `tee` で全出力をファイルに残してから `grep` する)。Issue #9 で `make tests 2>&1 | tail -80` の exit code が tail の 0 に隠れて、`make: *** [unit-tests] Error 70` という失敗を「成功」と誤判定する事故が発生した。**注意: このプロジェクトの shell は zsh。`${PIPESTATUS[0]}` は zsh では空文字を返す (bash 専用構文) ため silent no-op になる。zsh では `${pipestatus[1]}` (小文字・1-indexed) を使うか、`set -o pipefail` を前置するか、xcodebuild/make は出力中の `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` / `Error 6x` / `** TEST FAILED **` 等の成功・失敗マーカーで判定する。Issue #39 で subagent が `${PIPESTATUS[0]}` を使い空が返ったが、成功マーカーで代替判定して事なきを得た。**
- Plan / spec / design doc を書く時、他 Issue コメントや過去 commit で言及されている tool / script / path をそのまま引用するのは禁止。書く前に Glob か Read で実在を 1 回確認する。Why: 二次情報を primary source 扱いすると、実行時に subagent が BLOCKED で戻り「巻き戻し → controller 補正 → 再開」のループが発生する (Issue #13 Part A で `bin/add-to-target.rb` が実は `app/bin/` 配下にあった事例)。How to apply: plan を commit する前のセルフレビューで、参照している全ての tool/script path を 1 度 Glob する。
- macOS `base64 -i <file>` のデフォルト出力は 76 文字で line-wrap される。clipboard 経由で App Store Connect / CI Secret UI のような単一行入力欄に貼り付けると、改行が silently 落ちて Secret が壊れる。`base64 -i ... | tr -d '\n' | pbcopy` で 1 行化してからコピーする。Why: 復元時に base64 -d が静かに失敗 or 部分的なデータが流れて、CI build が後段で意味不明な失敗を起こす。How to apply: 任意の CI Secret 投入手順 (Xcode Cloud / GitHub Actions / Bitrise / fastlane match) を docs に書く時、base64 → clipboard の間に `tr -d '\n'` を必ず挟む。
- Explore agent / Glob-grep agent に UI component や view / function の「問題箇所」を返させる時、agent 指示書に **「そのファイル / シンボルが live コード (App entry / ViewModel / wire-up された View hierarchy) から参照されているかを `grep` で verify し、`live` か `dead/unused` の判定を付ける」** を必ず含める。Why: dead code (refactor 途中で wire-up 忘れ等) を修正してもユーザー価値ゼロで、spec scope の見積もりが狂い、結果的に「巻き戻し → spec amend → 再 plan」のループが発生する (Issue #26 で `SessionStatsView` / `TimerControlsView` を hardcoded color の修正対象として spec 化しかけたが、grep の結果 dead code と判明し scope 縮小した事例)。How to apply: `superpowers:daily-issue-triage` / `superpowers:brainstorming` の Step 3 (Explore dispatch) では、prompt の最後に「report each finding as live (used in production path) or dead (no live ref via grep)」を必ず追記する。
- 破壊的操作 (`rm` / `git reset` / 既存ファイル上書き等) は、ユーザーの literal turn にファイル名が含まれるまで実行しない。Why: `AskUserQuestion` の選択肢ラベル (`Recommended` 含む) は auto mode classifier に「明示指示」として認められず、確認なしで `rm` を撃つと連続ブロックされる。SessionStart hook が `pending-reflection.md` のような pending file を生成する運用が続く限り再発する。How to apply: destructive 系は **user 自身の turn に対象ファイル名が出るまで実行しない**。Issue #47 で、assistant がファイル名を提示し user が「両方OK」と短く同意しただけでは削除が通らなかった — **この安全側の挙動は正しい**。assistant 主導の削除提案に user が「OK」と返すだけでは authorization として扱わず、(i) user 自身にファイル名を述べてもらう、または (ii) user に `! rm <path>` で自分で実行してもらう、のいずれかで進める。承諾の取り方を工夫してブロックを回避するのではなく、ユーザーの明示的意思を正面から確認することが目的。
- 検査・linter・validator・checker 系ツールを作る／レビューする時、本体は **FAIL(RED) パス**。「壊れた入力を渡したら正しく RED になるか」を scratch repo / fixture で実証する。正常系が GREEN なだけの確認は "vacuously green" で checker 最大の盲点。Why: Issue #11 では advisor + scratch repo の往復で、コードを1行も書く前に false-green バグを3件潰せた (`git status --ignored` は tracked ファイルに盲目 / exit code は negation で反転 / dir-only パターン×不在パスの取りこぼし)。How to apply: checker 実装の plan には必ず「意図的に壊した入力で RED を確認」する RED ステップを入れる。
- 記録済みの教訓・MEMORY を適用する時、**その制約が literal に禁じている対象だけ**に適用し、広い禁止へ過剰一般化しない。Why: Issue #11 で「`git check-ignore` の **exit code** を信じるな」という MEMORY を「check-ignore 自体を使うな」と読みかけたが、実際は exit code がダメなだけで **出力 (last-matched rule) のパースは可**。狭い禁止を全面禁止に膨らませると正しい解法を捨てる。How to apply: MEMORY/教訓を引く時、禁止対象が「ツールそのもの」か「特定の使い方 (exit code / 特定フラグ)」かを一度切り分けてから適用する。

### プロジェクト固有の制約

- Xcode Cloud Workflow の "scheme may only exist locally" 警告は、scheme が shared + git tracked + remote push 済みなら基本 false positive。Why: 実 build log で `Cannot find scheme` が出ていなければ build 自体は通っているので、警告メッセージそのものを起点に scheme 設定を弄ると無駄な往復が増える。How to apply: 次回 Xcode Cloud の scheme 警告対応時は、scheme 設定を疑う前に最新 build log を `Cannot find scheme` 等のエラー文字列で grep し、build error が無ければ警告は無視する。
- `app/.gitignore` の `*.xcworkspace` ワイルドカードは `xcshareddata/swiftpm/Package.resolved` を巻き込む。Why: Issue #31 で SPM 依存追加時に `Package.resolved` が commit されず Xcode Cloud の dependency 解決が失敗した実害があった。How to apply: SPM 依存を追加・更新する時は `git status` に `Package.resolved` が出るかを必ず確認し、出ていなければ `git add -f` で強制 add するか `.gitignore` の whitelist (`!**/Package.resolved`) を追加する。
- 新規 Swift ファイルを Xcode project に追加すると `project.pbxproj` の children グループが未ソート状態になる。`make sort` を**最終 commit の前に**実行すること。実行を忘れると PR 作成直後に「1 uncommitted change」warning として表面化し、cosmetic 差分の追い commit が 1 回余計に発生する (Issue #8 で `make sort` 漏れが PR 化後に発覚した)。How to apply: 新規ファイル追加を含むブランチでは push/PR 前のセルフチェックに `make sort && git status` を入れる。
- 新規 Swift ファイルを追加したら `make precheck` (= `bin/xcode-precheck.rb`) で **target attach 漏れ (orphan)** と **Makefile destination のシミュレータ不在**を検証する。`make tests` の先頭に組み込み済みなので通常は自動で走るが、`make tests` を回さず commit する時は単体で `make precheck` を実行する。Why: ディスクに `.swift` があってもどの target にも attach されていないと**ビルドにもテストにも含まれず silent に無視される** (Issue #15)。既存の 14 orphan は `bin/xcode-precheck-orphans.txt` で grandfather 済みなので、**新規** orphan だけが fail する。orphan を意図的に未配線にする場合は `ruby bin/xcode-precheck.rb --update-baseline` で baseline に追加する (Issue #10)。追記 (Issue #47/PR #49): この 14 orphan は全て 2025-09 の放棄された旧実装と判明し削除、baseline は空になった。**orphan baseline の file はどの target にも未配線=ビルド非対象なので、live コードが参照していればビルドが落ちる → liveness はビルド成立で実質決着済み**。「各ファイルを grep で live 参照チェック」を素朴にやると、dead クラスタ内の相互参照 (例: `ComponentLibrary`→`Buttons`) や test の自己参照で **false な "live" hit** が出る (#26 の罠)。orphan cleanup は「liveness grep」ではなく「放棄→削除 / 配線忘れ→attach の**意図判断**」として扱い、判断材料は `git log` の最終更新時期 + live 等価実装の有無にする。
- `make tests` の依存チェーン (`precheck` 等) に Apple 同梱外の言語ツールチェイン (ruby gem 等) を足す時は、`require` を `rescue LoadError` でガードして gem 不在でも green を維持するか、CI hook で install する。Why: Issue #10 で `make tests → precheck → require 'xcodeproj'` を足したが、gem 不在環境ではテスト 1 件走る前に LoadError で build が red になるところだった (advisor 指摘で事前回収し rescue ガードを追加)。How to apply: `make` ターゲットの prerequisite に新スクリプトを足す時、そのスクリプトが require/import する非標準ライブラリを列挙し、無くても致命的でないものは rescue で skip にフォールバックさせる。
- トップ画面 (`TimerView`) の背景は `TimerViewModel+extensions.swift` の `getBackgroundColor(colorScheme:)` で **work/break × light/dark の4状態**に変化する (light は淡色・dark は濃色)。この背景の上に重ねる overlay UI は、ハードコード色 (例: `rgba(255,255,255,.x)` 相当の固定白) を使うと light モードで不可視になる。`.ultraThinMaterial` + semantic color (`.primary` / `.secondary` / `.green` / `.orange` 等の adaptive 色) を使い、**Simulator で4状態 (×ロケール) を必ず目視検証**する (`xcrun simctl ui <SIM> appearance light|dark` + `-AppleLanguages`)。Why: Issue #39 でブラウザモックが dark+work の1状態しか検証しておらず、light モードの material 可読性が盲点だった (advisor 指摘で事前回収)。
- このリポジトリの default branch は **`master`** (`main` ではない)。`daily-issue-triage` 等の skill boilerplate が `git checkout main` を前提にしており、しかも **parallel Bash batch 内で1コマンドが失敗すると同バッチの全コマンドが cancel** され、結果が partial / 前後して「出力が壊れた」ように見える。Why: Issue #11 のセッション冒頭で open issue を誤認する事故が起きた。How to apply: ツール不調を疑う前にバッチ内に失敗コマンド (master repo での `checkout main` 等) が混ざっていないか確認し、read-only な状態確認クエリと失敗しうる `git checkout` は別バッチに分ける。

### 効率化ルール

- 新規 hook スクリプト（SessionEnd/SessionStart など）を settings.json に配線する前に、sample JSON を stdin に pipe-test して bail 条件・self-detach・sentinel ガードを単体検証する。配線後の silent failure（特に `claude -p --bare` の OAuth 切れのような沈黙失敗）を未然に検出できる。
- plan-driven な PR では、Issue #15 の `f2df20e` の convention に倣い、**実装の最初のコミットとして** `docs/superpowers/plans/<date>-<feature>.md` を含める。PR 作成後の追い commit になると CI 履歴とレビュー導線がズレるため、ブランチ作成直後に plan を commit する。
- ブランチ push や `gh pr create` の前に、必ず `git fetch && gh pr list --state all --head <branch>` で既存 PR / merge 状況を確認する。ローカル master が古いまま push して「既に MERGED」で空振りするのを防ぐ。
- `superpowers:subagent-driven-development` を採用する時、Plan の Task が「観察+編集+検証+commit」のような小粒で密接結合なら、Task ごとに subagent を dispatch せず**複数 Task を 1 subagent に full text で束ねて渡す**。レビューはまとめて 2 段階 (spec compliance → code quality) で実施する。Why: 個別 dispatch のオーバーヘッド (context 渡し / Tool 再 load / agent boot) > 実行コストになることがある。Issue #16 で Plan の Task 2-6 を 1 subagent に束ね、起動コストを抑えつつ品質ゲートは両 reviewer で確保できた。
- Agent tool 経由で subagent に `cd app && make unit-tests` を実行させる時、Bash の `timeout` を明示的に `600000` (10 分) に設定するよう subagent 指示書に書く。Why: xcodebuild + simulator boot + test 実行で 2〜5 分かかるため、Bash のデフォルト 2 分でタイムアウトすると、せっかくのテスト実行が無駄になる。
- マネージド CI runner (Xcode Cloud / GitHub-hosted runner 等) は Apple 同梱以外の言語ツールチェイン (CocoaPods / Bundler 等) の preinstall を保証しない。`ci_post_clone.sh` のような CI hook の冒頭で必要なツールを明示的に `brew install` / `gem install` してから本処理に入る。Why: ローカルでは `pod install` が動くため見落としやすく、初回本番ビルド時に silent break する。How to apply: 新規 CI hook を書く時、ローカル前提のツール (cocoapods / bundler / yarn / poetry 等) があるかチェックし、ある場合は `set -euo pipefail` 配下で install ステップを先頭に追加する。
- SwiftLint 組み込み `empty_count` rule は tuple の Int field など `.isEmpty` を使えない箇所でも `.count == 0` を検出する。新規コードでは可能な限り `.isEmpty` を使い、Int field 等で不可避な場合のみ `// swiftlint:disable:next empty_count` で 1 行 suppress する。Why: Issue #8 では test 内の `(date, count)` tuple 比較で違反が `make tests` 段階まで検出されず、最後に suppress 対応が発生した。
- `gh pr create` の本文 (markdown) は **ローカルファイルパスの画像を埋め込めない**。`![](/tmp/foo.png)` と書いても GitHub は到達可能な URL しか取得しないため、空表示になる (`gh` に upload-and-embed フラグは無い)。iOS の PR スクリーンショットは `SendUserFile` でユーザーに渡し、PR 説明欄に「スクリーンショット」セクションの枠だけ用意して、**ユーザーがブラウザでドラッグ&ドロップ添付**する運用にする。`/tmp` パスを本文に書いて「スクショ添付済み」と主張しない。Why: Issue #39 で 4状態スクショを PR に載せる際に発覚 (advisor 指摘)。
- 「スキル化候補」issue を着手する前に、チェック内容が**機械的 (regex/script で検証可能) か判断的か**を見極める。機械的かつプロジェクト固有なら `~/.claude/skills/` のドキュメントスキルではなく **repo 内スクリプト + `make` ターゲット**として実装する (`writing-skills` のガイダンス: 機械的チェックは自動化・固有規約はリポジトリに置く)。Why: Issue #10 で当初「スキル新設」前提だったが、3 チェック全てが機械的+固有と判明し doc スキルなら無駄になるところだった (advisor 指摘で着手前に scope 再確認)。How to apply: `daily-issue-triage` でスキル化候補 issue を分類する時、各チェックが script で書けるか自問し、書けるなら downstream を `writing-skills` ではなく repo スクリプト + TDD に向ける。

