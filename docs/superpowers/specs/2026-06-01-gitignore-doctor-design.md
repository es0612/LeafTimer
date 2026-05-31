# gitignore-doctor 設計 (Issue #11)

- **Issue**: #11 「Claude Code スキル化候補: gitignore-doctor（ignore パターン検証）」
- **作成日**: 2026-06-01
- **ブランチ**: `feature/11-gitignore-doctor`

## 目的

`.gitignore` の **意図（keep したい / ignore したいパス）と git の実挙動のズレ**を
機械的に検出する。次の両方向の事故を再発防止する:

- **Issue #9 型**: アンカー漏れ。`plans/`（スラッシュ無し＝任意深度マッチ）を足したら
  `docs/superpowers/plans/` まで巻き込んだ。本来 commit したいファイルが silently ignore される。
- **Issue #31 型**: 逆方向。`*.xcworkspace` ワイルドカードが
  `LeafTimer.xcworkspace/.../Package.resolved` を巻き込み、Xcode Cloud の依存解決が失敗した。
  whitelist (`!`) が効いているかを毎回手で確認するのは漏れる。

## スコープと前提（重要な設計判断）

Issue 素案には、このリポジトリの確立済みの学びと**衝突する前提が2つ**あったため、
ブレストで明示的に上書きした:

1. **配置**: Issue 素案は `~/.claude/skills/` への doc スキル新設を想定。
   → CLAUDE.md の学び「機械的かつプロジェクト固有なチェックは doc スキルではなく
   **repo スクリプト + make ターゲット**にすべき」に従い、repo 内スクリプトとして実装する。
   （`writing-skills` のガイダンス: 機械的チェックは自動化・固有規約はリポジトリに置く）

2. **判定コマンド**: Issue 素案は `git check-ignore -v` を想定。
   → MEMORY `feedback-gitignore-check-ignore-semantics`（実機検証済み）に従い **使わない**。
   `git check-ignore -v` は「最後にマッチしたルール」を返すコマンドで、それが `!`（再 include）
   であっても **exit 0** を返すため、whitelist が効いているかの oracle にならない。
   代わりに `git status --ignored` の出力セクション（Ignored / Untracked）と `git ls-files` で判定する。

## アーキテクチャ

既存の `xcode-precheck` と同じ **2層 + テスト**構造に揃える（命名規約も踏襲）。

| ファイル | 役割 | テスト |
|---|---|---|
| `app/bin/gitignore_doctor.rb` | **純粋関数モジュール** `GitignoreDoctor`。fixture パース・git 出力パース・判定。I/O なし | ✅ minitest |
| `app/bin/gitignore-doctor.rb` | **実行スクリプト**。fixture 読込 → `git` 実行 → モジュールに渡す → 結果表示・exit code | 実行で確認 |
| `app/bin/gitignore-doctor-expectations.txt` | **期待 fixture**。`keep:` / `ignore:` 行 + `#` コメント | — |
| `app/bin/test_gitignore_doctor.rb` | 純粋関数の minitest | ✅ |

> **命名規約**: 純粋ロジックは `gitignore_doctor.rb`（アンダースコア）、実行は
> `gitignore-doctor.rb`（ハイフン）。既存の `xcode_precheck.rb` / `xcode-precheck.rb`
> と全く同じ命名規約。実行スクリプトが `require_relative 'gitignore_doctor'` する。

- 言語: **Ruby**（標準ライブラリのみ・gem 不要）。`xcode-precheck.rb` と同言語・同パターン。
- 純粋関数を I/O から分離することで、`git` を実行せずに判定ロジックを全部テストできる
  （xcode-precheck が `simctl` 出力をテキスト fixture でテストしているのと同じ流儀）。

## データフロー

```
expectations.txt        git の真実
  keep:  PATH    ──┐    ┌── `git status --ignored --porcelain` (ignore されているか)
  ignore: PATH   ──┼──→ ┤
                   │    └── `git ls-files <path>` (tracked か)
                   ▼
        GitignoreDoctor.evaluate(expectations, git_state)
                   ▼
          violations[] → 0件なら exit 0 / 1件以上 exit 1
```

実行スクリプト側**だけ**が `git` を叩き、パース結果を純粋関数に渡す。

## 判定ロジック（心臓部）

| 宣言 | 期待される状態 | NG（FAIL）条件 | 判定 |
|---|---|---|---|
| `keep: PATH` | commit 可能（ignore されていない） | **ignore されている** | `git status --ignored` の Ignored セクション(`!!`)に出たら NG |
| `ignore: PATH` | ignore される | **ignore されていない** | tracked、または Untracked(`??`)で見えていたら NG |

### `keep:` で物理ファイルが存在しない場合

- **警告のみ・FAIL しない**（exit code に影響させない）。
- 理由: ファイルが単に削除/未生成なだけの可能性があり、それを CI failure にすると
  「ファイルを消したら gitignore-check が落ちる」という無関係な赤を生む。
- `ignore:` 側は物理ファイル不要（gitignore はパターンなので、存在しないパスでも
  「ignore 対象であること」自体は検証意味があるが、判定は status 出力に依存するため
  実務上は「存在しなければ Untracked にも Ignored にも出ない＝NG にしない」扱い）。

## コンポーネント境界（純粋関数 `GitignoreDoctor`）

すべて I/O なし。

- `parse_expectations(text)` → `[{kind: :keep|:ignore, path: String}]`
  - `#` コメント行・空行スキップ（xcode-precheck の baseline パース流用）
  - 行形式: `keep: <path>` / `ignore: <path>`（コロン後の空白は寛容に trim）
- `parse_git_status(porcelain_text)` → `{ignored: Set<String>, untracked: Set<String>}`
  - `git status --ignored --porcelain` の `!!` プレフィックス → ignored、`??` → untracked
  - ディレクトリは末尾 `/` を含む形で出ることがあるため、パス正規化を1箇所に集約
- `evaluate(expectations, git_state, tracked_paths:)` → `[{path, kind, expected, actual, message}]`
  - keep が ignored に含まれる → violation（#31 シナリオ）
  - ignore が tracked または untracked に含まれる → violation（#9 シナリオ）

## エラーハンドリング & エッジケース

- **fixture が存在しない**: スキップ（⚠️ 表示）して exit 0。導入直後に空でも壊れない。
- **fixture が空**: 「期待0件」で exit 0（xcode-precheck baseline 空の現状と同じ哲学）。
- **`keep:` の物理ファイル無し**: 警告のみ、FAIL しない（上述）。
- **git コマンド失敗**: stderr 表示して exit 1。
- **パス正規化**: 末尾スラッシュ・先頭 `./` のゆれを `evaluate` 前に吸収。

## テスト戦略（TDD）

`test_gitignore_doctor.rb` で純粋関数を minitest 検証。最低限:

1. `parse_expectations`: `keep:`/`ignore:` 行分類、`#` コメント・空行スキップ
2. `parse_git_status`: `!!path`（ignored）と `??path`（untracked）の分類
3. `evaluate` — keep が ignore されてたら violation（#31 シナリオ）
4. `evaluate` — ignore したいのに untracked で見えてたら violation（#9 シナリオ）
5. `evaluate` — 全て期待どおりなら violations 空
6. パス正規化（末尾 `/`・先頭 `./` のゆれ）

実装は **TDD**: テストを先に書き、red → green の順で進める。

## 配線

`app/Makefile` に独立ターゲットを追加:

```makefile
gitignore-check:
	@echo "Running gitignore-doctor..."
	@ruby bin/gitignore-doctor.rb
```

- **`make tests` には入れない**（最初は手動）。fixture と実態のていれで誤検出 → 無関係な
  tests 赤、を避ける。実績を見てから `precheck` への昇格を検討する。
- 実行タイミング: `.gitignore` / `expectations.txt` を編集した時に手動で回す。

## 初期 fixture（expectations.txt）

このリポジトリの既知の意図を初期値として明記する（事故の再発検出になる）:

```
# gitignore-doctor expectations — declares intended keep/ignore paths.
# `keep:`   = must be committable (NOT ignored). Catches #31-type accidents.
# `ignore:` = must be ignored. Catches #9-type anchor-leak accidents.
# Lines starting with # and blank lines are skipped.

# --- #31: Package.resolved must survive the *.xcworkspace wildcard ---
keep:   app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved

# --- #9: plan dirs must be anchored so docs/.../plans is not swallowed ---
keep:   docs/superpowers/plans

# --- things that genuinely must stay ignored ---
ignore: app/Pods
ignore: /plans
```

（初期 fixture の具体的な行は実装時にリポジトリ実態と突き合わせて最終確定する。）

## スコープ外（YAGNI）

- ❌ `.gitignore` 編集の差分トリガー（make 同梱と相性が悪い）
- ❌ pre-commit hook（`.git/hooks` は git 管理外で共有困難）
- ❌ パターンの静的 lint（アンカー漏れ regex 検出）— 誤検出が多く、意図アサーション方式が上位互換
- ❌ 横断スキル化（CLAUDE.md の学びに従い repo に閉じる）

## 関連

- Issue #9（アンカー漏れの原体験、コミット 9862e96 → da32d01 の手戻り）
- Issue #31（Package.resolved が `*.xcworkspace` に巻き込まれた事故）
- MEMORY `feedback-gitignore-check-ignore-semantics`（check-ignore を使わない理由の実機検証）
- 既存実装パターン: `app/bin/xcode-precheck.rb` / `xcode_precheck.rb` / `test_xcode_precheck.rb`
