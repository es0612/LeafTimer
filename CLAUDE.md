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
- Bash でビルド/テスト系コマンド (`make` / `xcodebuild` / `npm test` / `pytest` 等) を `| tail` / `| head` / `| grep` でフィルタする時は、必ず `set -o pipefail` をコマンド前に置くか、`${PIPESTATUS[0]}` で元コマンドの exit code を取得する (または `tee` で全出力をファイルに残してから `grep` する)。Issue #9 で `make tests 2>&1 | tail -80` の exit code が tail の 0 に隠れて、`make: *** [unit-tests] Error 70` という失敗を「成功」と誤判定する事故が発生した。

### 効率化ルール

- 新規 hook スクリプト（SessionEnd/SessionStart など）を settings.json に配線する前に、sample JSON を stdin に pipe-test して bail 条件・self-detach・sentinel ガードを単体検証する。配線後の silent failure（特に `claude -p --bare` の OAuth 切れのような沈黙失敗）を未然に検出できる。
- plan-driven な PR では、Issue #15 の `f2df20e` の convention に倣い、**実装の最初のコミットとして** `docs/superpowers/plans/<date>-<feature>.md` を含める。PR 作成後の追い commit になると CI 履歴とレビュー導線がズレるため、ブランチ作成直後に plan を commit する。
- ブランチ push や `gh pr create` の前に、必ず `git fetch && gh pr list --state all --head <branch>` で既存 PR / merge 状況を確認する。ローカル master が古いまま push して「既に MERGED」で空振りするのを防ぐ。
- `superpowers:subagent-driven-development` を採用する時、Plan の Task が「観察+編集+検証+commit」のような小粒で密接結合なら、Task ごとに subagent を dispatch せず**複数 Task を 1 subagent に full text で束ねて渡す**。レビューはまとめて 2 段階 (spec compliance → code quality) で実施する。Why: 個別 dispatch のオーバーヘッド (context 渡し / Tool 再 load / agent boot) > 実行コストになることがある。Issue #16 で Plan の Task 2-6 を 1 subagent に束ね、起動コストを抑えつつ品質ゲートは両 reviewer で確保できた。
- Agent tool 経由で subagent に `cd app && make unit-tests` を実行させる時、Bash の `timeout` を明示的に `600000` (10 分) に設定するよう subagent 指示書に書く。Why: xcodebuild + simulator boot + test 実行で 2〜5 分かかるため、Bash のデフォルト 2 分でタイムアウトすると、せっかくのテスト実行が無駄になる。

