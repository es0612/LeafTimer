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

2. **判定コマンド**: `git check-ignore --no-index -v <path>` の **出力（マッチしたルール行）**で判定する。
   MEMORY `feedback-gitignore-check-ignore-semantics` の教訓は「`git check-ignore` の **exit code** を
   信じるな（`!` 再 include でも exit 0 を返す）」であり、**出力のパースまでは否定していない**。
   本設計は exit code を一切使わず、出力のマッチルールが `!`（negation）で始まるかで判定するため、
   この教訓と矛盾しない（実機検証で確認済み・後述）。

   `git status --ignored` を**使わない**理由（実機検証で判明したブロッカー）:
   `git status --ignored` は **untracked パスしか `!!` で出さない**。tracked なファイルは .gitignore
   ルールに関係なく tracked のまま残り、`!!` に出ない。よって `keep:` を tracked ファイル
   （例: 既に commit 済みの `Package.resolved`）に設定すると、whitelist を壊しても status は
   緑のまま（vacuously green）で **#31 型の回帰を検出できない**。`check-ignore --no-index` は
   tracked/untracked・ディスク存在に依存せず .gitignore ルール自体を評価するためこの盲点がない。

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
expectations.txt              per-path に git へ問い合わせ
  keep:  PATH    ──┐
  ignore: PATH   ──┼──→ 各 PATH について実行:
                   │      `git check-ignore --no-index -v -- <PATH>`
                   │            │
                   │            ▼ (出力 = 0 or 1 行: "source:line:pattern\t<PATH>")
                   ▼      GitignoreDoctor.ignored?(check_ignore_output)
        GitignoreDoctor.evaluate(expectations, per_path_results)
                   ▼
          violations[] → 0件なら exit 0 / 1件以上 exit 1
```

実行スクリプト側**だけ**が `git` を **リポジトリルートで** path ごとに叩き、その生出力を
純粋関数に渡す。`check-ignore` に渡す `<PATH>` は fixture 記載の**リポジトリルート相対**パス。

## オラクル: `git check-ignore --no-index -v`（実機検証済み）

判定は exit code を使わず、**マッチしたルール行**を見る。

- 出力が**空** → どのルールにもマッチしない → **NOT ignored**
- 出力あり（`source:line:pattern\t<path>`）でマッチ `pattern` が `!` 始まり → **NOT ignored**（有効な negation）
- 出力ありでマッチ `pattern` が `!` 以外 → **IGNORED**

`--no-index` は tracked/untracked・ディスク存在に依存せず .gitignore ルールを評価する。
git は「親ディレクトリが除外されていれば配下の `!` 再 include は無効」というルールも
**評価済みの最終結果**としてマッチ行に反映する（実機確認: 階段状 whitelist を `ws/` 一発に
簡略化すると、`!…Package.resolved` ではなく効いている `ws/` がマッチ行として返る → 正しく IGNORED 判定）。
ディレクトリパス（末尾スラッシュ有無どちらでも）も正しくマッチする（実機確認済み）。

## 判定ロジック（心臓部）

| 宣言 | 期待される状態 | NG（FAIL）条件 | 判定 |
|---|---|---|---|
| `keep: PATH` | ignore されない（commit 可能） | **ignored** | `ignored?(output)` が true なら violation（#31 型） |
| `ignore: PATH` | ignore される | **NOT ignored** | `ignored?(output)` が false なら violation（#9 型） |

### `keep:` で物理ファイルが存在しない場合

- **判定に影響しない**（物理存在チェックはしない）。
- 理由: `--no-index` はディスク上のファイル有無と無関係に .gitignore パターンを評価するため、
  「ファイルが消えている → status に出ない → 緑」という旧 status 方式の盲点が**そもそも無い**。
  パターンとしての ignore 判定は物理ファイルなしでも成立する。

## コンポーネント境界（純粋関数 `GitignoreDoctor`）

すべて I/O なし。

- `parse_expectations(text)` → `[{kind: :keep|:ignore, path: String}]`
  - `#` コメント行・空行スキップ（xcode-precheck の baseline パース流用）
  - 行形式: `keep: <path>` / `ignore: <path>`（コロン後の空白は寛容に trim）
- `ignored?(check_ignore_output)` → `Boolean`
  - 入力は `git check-ignore --no-index -v -- <path>` の生出力（0 or 1 行の String）
  - 空文字列 → false
  - 1 行ある場合: **TAB で先割り**して左辺 `source:line:pattern` を取り、先頭の `source:line:`
    （`^[^:]*:\d+:`）を strip して `pattern` を得る。`pattern` が `!` 始まりなら false、それ以外 true。
  - ⚠️ `sed 's/.*://'` のような末尾貪欲マッチは `:` を含むパターンで壊れるため使わない。
    必ず TAB 先割り → 行頭 `source:line:` のみ除去。
- `evaluate(expectations, results)` → `[{path, kind, expected, actual, message}]`
  - `results` は `path → check_ignore_output(String)` の Hash（実行スクリプトが収集）
  - `kind == :keep` かつ `ignored?` が true → violation（#31 シナリオ）
  - `kind == :ignore` かつ `ignored?` が false → violation（#9 シナリオ）

## エラーハンドリング & エッジケース

- **fixture が存在しない**: スキップ（⚠️ 表示）して exit 0。導入直後に空でも壊れない。
- **fixture が空**: 「期待0件」で exit 0（xcode-precheck baseline 空の現状と同じ哲学）。
- **`keep:` の物理ファイル無し**: 判定に影響しない（上述）。
- **git コマンド失敗**（リポジトリ外など）: stderr 表示して exit 1。
- **パス正規化**: fixture は repo ルート相対で書く。`check-ignore` は `--no-index` なので
  ディスク存在に依存しないが、末尾 `/`・先頭 `./` のゆれは `parse_expectations` で吸収。

## テスト戦略（TDD）

`test_gitignore_doctor.rb` で純粋関数を minitest 検証（git 実行なし・出力テキストを fixture 化）。最低限:

1. `parse_expectations`: `keep:`/`ignore:` 行分類、`#` コメント・空行スキップ、末尾 `/`・先頭 `./` 吸収
2. `ignored?`: 空出力 → false
3. `ignored?`: `!` 始まりルール行 → false（有効 negation）
4. `ignored?`: 通常ルール行 → true
5. `ignored?`: パターンに `:` を含む行でも TAB 先割りで正しく抽出（脆い末尾マッチ回帰防止）
6. `evaluate` — keep が ignored なら violation（#31 シナリオ）
7. `evaluate` — ignore が NOT ignored なら violation（#9 シナリオ）
8. `evaluate` — 全て期待どおりなら violations 空

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
ignore: plans
```

- fixture のパスは **repo ルート相対**で書く（先頭スラッシュ無し）。`git check-ignore` に
  渡す引数の `/plans` は「絶対パス」と解釈されうるため、ルート相対の `plans` と書く。
  これは `.gitignore` 側の `/plans`（アンカー）とは別概念（fixture = 検査対象パス、
  `.gitignore` = ルール）。
- （初期 fixture の具体的な行は実装時にリポジトリ実態と突き合わせ、`make gitignore-check` が
  green になることを確認して最終確定する。）

## スコープ外（YAGNI）

- ❌ `.gitignore` 編集の差分トリガー（make 同梱と相性が悪い）
- ❌ pre-commit hook（`.git/hooks` は git 管理外で共有困難）
- ❌ パターンの静的 lint（アンカー漏れ regex 検出）— 誤検出が多く、意図アサーション方式が上位互換
- ❌ 横断スキル化（CLAUDE.md の学びに従い repo に閉じる）

## 関連

- Issue #9（アンカー漏れの原体験、コミット 9862e96 → da32d01 の手戻り）
- Issue #31（Package.resolved が `*.xcworkspace` に巻き込まれた事故）
- MEMORY `feedback-gitignore-check-ignore-semantics`（**exit code** は信じない／`-v` 出力の
  last-rule パースは有効、という制約の実機検証。本 issue 着手時に更新する）
- 既存実装パターン: `app/bin/xcode-precheck.rb` / `xcode_precheck.rb` / `test_xcode_precheck.rb`
