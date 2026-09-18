# checker 群の堅牢化バンドル (#152 / #153 / #154 / #155) 設計

- 日付: 2026-09-18
- 対象 issue: #152 (ViewInspector strict pin) / #153 (archive 忘れの検出) / #154 (checker 依存の堅牢化) / #155 (失敗理由の文言)
- 起点: PR #156 (#78/#149/#84 バンドル) の final review で分離された 4 件
- スコープ: PR 作成まで (merge はレビュー通過後にコントローラが CLAUDE.md ルール 24 のチェーンで行う)

## 背景

PR #156 で 3 つのゲート (テスト方針の明文化 / Podfile のバージョン制約 / plan-docs-check) を入れたが、final review が「入れたゲート自身の穴」を 4 件検出し、それぞれ独立 issue に分離した。4 件はいずれも `app/bin/` の checker 群と依存宣言、および CLAUDE.md の文言という同一領域に収まるため、1 PR にまとめる (CLAUDE.md ルール 20: 小粒で密結合な Task 群は束ねる)。

いずれも「本番アプリのコードには触れない」。変更対象は開発ループ側のゲートのみ。

## 決定事項 (2026-09-18 の brainstorming で確定)

| 論点 | 決定 | 理由 |
| --- | --- | --- |
| #152 pin の範囲 | **ViewInspector のみ strict pin (`'0.10.3'`)**。Quick / Nimble は `~>` 据え置き | patch 差で結果が反転した実例 (#73 / PR #150) があるのは ViewInspector だけ。証拠のある側だけ厳しくする |
| #153 検出方式 | **(a) 日付ベースの滞留検出、閾値 14 日** | オフラインで完結し、`gh` 依存を持ち込まない。CLAUDE.md ルール 9「仕組み > 気合い」に沿う |
| #153 issue 未確定 doc の置き場 | **issue 先行を徹底し、失敗メッセージで誘導** | ディレクトリと規則を増やさない (YAGNI)。仕組みは既にあり、欠けているのはヒントだけ |

## 変更対象

| ファイル | 変更 | issue |
| --- | --- | --- |
| `app/Podfile` | `pod 'ViewInspector', '0.10.3'` + コメント修正 | #152 |
| `app/Podfile.lock` | `bundle exec pod install` で再生成 | #152 |
| `app/Gemfile` / `app/Gemfile.lock` | `gem "minitest", "~> 5.27"` を明示宣言 | #154 |
| `app/bin/gitignore-doctor-expectations.txt` | `keep: docs/superpowers/specs/` を 1 行追加 | #154 |
| `app/bin/plan_docs_check.rb` | `root_reason` 分岐の並べ替え + 滞留検出 | #155 / #153 |
| `app/bin/plan-docs-check.rb` | `today:` の注入、失敗メッセージに issue 誘導 1 行 | #153 |
| `app/bin/test_plan_docs_check.rb` | RED テスト追加 | #153 / #155 |
| `CLAUDE.md` | ルール 43 / ルール 44 の改訂 | #152 / #153 |

## 設計

### 1. ViewInspector の strict pin (#152)

`app/Podfile` のテスト用 pod を次にする。

```ruby
pod 'Quick', '~> 7.6'
pod 'Nimble', '~> 13.7'
pod 'ViewInspector', '0.10.3'
```

実測済みの事実 (`app/Podfile.lock`):

- `PODS:` の解決バージョンは既に `ViewInspector (0.10.3)` なので、**pod バイナリは変わらない**
- 変わるのは `DEPENDENCIES:` の `- ViewInspector (~> 0.10.3)` → `- ViewInspector (= 0.10.3)` の 1 行と `PODFILE CHECKSUM` の 1 行

Quick / Nimble を `~>` のまま残すのは意図的。`~>` は「major 越えを止める」ことには成功しており、この 2 つには patch 差で挙動が変わった実例がない。3 つとも strict にすると、証拠のない 2 つにも手動アップグレードの手間が恒常的にかかる。

### 2. plan の滞留検出 (#153)

最終的な設計では `PlanDocsCheck.violations` のシグネチャは変えず (既存 13 テストを日付非依存に保つため)、滞留判定は独立した `PlanDocsCheck.stale(root_names:, today:, threshold_days: STALE_DAYS)` に分離した (brief が本節の初期案を上書き)。

```ruby
def self.stale(root_names:, today:, threshold_days: STALE_DAYS)
```

`today` を注入するのは、純粋関数の中で `Date.today` を呼ぶとテストが日付依存で非決定的になるため。CLI (`bin/plan-docs-check.rb`) が `Date.today` を 1 回だけ取得し `stale` に渡す。

判定は **ファイル名の日付プレフィックス**に対して行う。mtime を使わないのは、`git checkout` / fresh clone で mtime がチェックアウト時刻になり、滞留を検出できなくなるため。

- 対象は `plans/` `specs/` の**直下のみ**。`archive/` は歴史なので古くて当然
- 命名違反と滞留違反は二重計上しない。命名が `ROOT_NAME` に適合したファイルだけを滞留判定にかける。ただし `ROOT_NAME` は日付部分の桁数しか見ず実在性 (2026-09-31 等) までは検証しないため、日付の実在性は `violations` 側 (`PlanDocsCheck.valid_date?`) でも判定し、実在しない日付を違反として報告する (fix round 1 F-1: 当初この括弧内は「日付プレフィックスが壊れていれば、そもそも `Date.parse` できない」としていたが誤りで、桁数だけ合って実在しない日付は `Date.parse` が例外を投げるまで気づけなかった)。**ただし `violations` を通すことは `stale` の入力を絞る効果を持たない** — `bin/plan-docs-check.rb` は同じ未フィルタの `root_names` を `violations` と `stale` の両方に渡すため。`stale` が全域関数であることを保証しているのは `stale` 自身の `next unless valid_date?(name)` というガードであり (fix round 2 N-1)、これは「violations が実在性を判定しているから冗長」な二重防壁ではない
- 閾値 `STALE_DAYS = 14`。`today - date > 14` で違反 (14 日ちょうどは許容)
- reason: `作成から NN 日経過している (PR 作成前に archive/ へ git mv する — CLAUDE.md ルール 44)`

物理的な帰結: master では merge 後に直下が空になるため、このゲートは master では常に緑。赤くなるのは「plan を書いてから 14 日以上 `gh pr create` していないブランチ」だけで、これはルール 44 が既に禁じている状態である。

### 3. 失敗理由の分岐の並べ替え (#155)

現在の `root_reason` は「日付 → issue-NN → slug → companion」の順で、`\.md` が case-sensitive なため拡張子が大文字の入力が手前の構成要素のせいに見える。

新しい順序と対応する sub-pattern:

| 順 | 判定 | 例 (違反する入力) |
| --- | --- | --- |
| 1 | 拡張子が小文字 `.md` か | `2026-09-12-issue-84-fixture.MD` |
| 2 | 日付プレフィックス | `dynamic-type-58.md` |
| 3 | `issue-NN` | `2026-08-13-dynamic-type-58.md` |
| 4 | slug の存在と文字種 | `2026-09-12-issue-84.md` (欠落) / `2026-09-12-issue-84-Foo.md` (大文字) |
| 5 | companion suffix | `2026-06-04-issue-48-x.1bad.md` |

`ISSUE_PREFIX` は現在末尾ハイフンまで要求するため、slug が無い名前は issue 番号ごとマッチしない。lookahead に変える。

```ruby
ISSUE_PREFIX = /\A\d{4}-\d{2}-\d{2}-issue-\d+(?:-\d+)*(?=[-.])/.freeze
```

正例 / 反例 (CLAUDE.md ルール 36 に従い両方向を列挙する):

- 正: `2026-09-12-issue-84-slug.md` / `2026-09-12-issue-86-78-149-84-bundle.md` / `2026-09-12-issue-84.md` (issue 部分だけは満たす)
- 反: `2026-09-12-slug.md` / `2026-09-12-issue--slug.md` / `2026-09-12-issueX-84-slug.md`

`archive/` 側の違反も同じ理由関数を通す。現在は無条件に「日付プレフィックスで始まっていない」と報告しており、`archive/2026-01-01-legacy.MD` に対して誤った理由を出す。

### 4. checker 群の依存の堅牢化 (#154)

`app/Gemfile` に 1 行足す。

```ruby
gem "minitest", "~> 5.27"
```

現在 `minitest (5.27.0)` は `cocoapods-core → activesupport` の transitive 依存としてのみ lock に入っている。`app/bin/test_*.rb` 7 本が素の `require 'minitest/autorun'` を使っているので、CocoaPods が activesupport を落とすと 7 本すべてが LoadError で壊れる。

`rescue LoadError` ガードは**足さない**。ガード付きの minitest は unit test を黙ってスキップし、CLAUDE.md ルール 27 が警告する silent green の罠そのものになる (PR #146 の I-1 で実測済み)。

`app/bin/gitignore-doctor-expectations.txt` に対称性のための 1 行を足す。

```text
keep:   docs/superpowers/specs/
```

現在 `plans/` `plans/archive/` `specs/archive/` の 3 つに `keep:` があり `specs/` (直下) だけ無い。実害は確認されていない (final review が `.gitignore` を実測し `specs` を飲み込むパターンは存在しないと確認) が、4 エントリの集合が網羅的であるかのように読める。

### 5. CLAUDE.md の改訂 (#152 の N1 / #153 の N2)

**ルール 43**: strict pin 導入に伴い、現在の `~>` 前提の記述を全面的に書き換える。現在の文面は以下 3 点を含んでおり、いずれも実態と合わなくなる。

1. 「`app/Podfile` のテスト用 pod は `~>` で制約する」→ ViewInspector だけ例外になる
2. 「`~>` は `>= 0.10.3, < 0.11.0` を意味し patch 更新は素通りする」→ ViewInspector には当てはまらなくなる
3. 「patch まで完全に固定したい場合は別途 strict pin の issue で検討する」→ #152 で決着済み

さらに N1 の指摘を反映する。現在の「`bundle exec pod update ViewInspector` を明示的に叩かない限り上がらない」は実態より狭い。`cocoapods-1.16.2/lib/cocoapods/installer/analyzer.rb:934-947` の実装では、引数なしの `bundle exec pod update` (`update_mode == :all`) と `Podfile.lock` の喪失 (`!lockfile`) も lock を無視する分岐に入る。

**ルール 44**: N2 の指摘を反映し、最終文の主語を正す。

- 現在: 「旧規則で書かれた歴史はリネームせず、日付プレフィックスのみを要求する。」
- 修正後: 「`archive/` 配下は日付プレフィックスのみを要求する (旧規則で書かれた歴史はリネームしない)。」

checker (`ARCHIVE_NAME`) の要求は `archive/` 配下**全体**に適用されるため、現在の文は主語が狭い。あわせて滞留検出 14 日の存在を 1 文で追記する。

改訂時は CLAUDE.md ルール 45 に従い、同じ話題を扱う既存行を `/usr/bin/grep` して自己矛盾を潰す。ルール 7 が `~> 0.10.3` を例示に使っているため、こちらも要確認。

`app/Podfile` のコメントブロック (現在 `~>` のセマンティクスを説明している) も同時に更新する。

## テスト戦略

TDD (RED → GREEN)。CLAUDE.md ルール 8 に従い「意図的に壊した入力で正しく RED になる」ことを fixture で実証する。

### RED テスト

1. **#155 の 3 ケース** — 各入力に対して reason の文言が正しい構成要素を指すことを assert
   - `plans/2026-09-12-issue-84-fixture.MD` → 拡張子
   - `plans/archive/2026-01-01-legacy.MD` → 拡張子
   - `plans/2026-09-12-issue-84.md` → slug の欠落
2. **滞留検出の境界値 3 点** — `today` を固定して 13 日 / 14 日 / 15 日
   - 13 日 → 違反なし、14 日 → 違反なし (ちょうどは許容)、15 日 → 違反 1 件
3. **既存テストの巻き込み** — 現在の `test_plan_docs_check.rb` は reason 文字列を assert しているため、分岐を入れ替えると既存も割れる。plan 作成時に「並べ替え後に何件 RED になるか」を scratchpad で実測し、その数値を plan に書く (ルール 7)

### mutation

ルール 8 に従い、新規に強化した全テストを対象にする。

- `STALE_DAYS` を 14 → 9999 に変えて滞留テストが fail することを確認
- `ISSUE_PREFIX` の lookahead を元の末尾ハイフン要求に戻して slug 欠落テストが fail することを確認
- 拡張子分岐を削除して 2 件の拡張子テストが fail することを確認

想定 fail 件数は plan 作成時に実測して記載する。

## 検証手順

1. `cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec ruby bin/test_plan_docs_check.rb`
2. `cd /Users/shinya/workspace/claude/LeafTimer/app && bundle exec pod install`
3. `cd /Users/shinya/workspace/claude/LeafTimer/app && make cocoapods-lock-check`
4. `cd /Users/shinya/workspace/claude/LeafTimer/app && make sort` — pbxproj の差分が空であることを確認 (CLAUDE.md ルール 28)
5. `cd /Users/shinya/workspace/claude/LeafTimer/app && make tests` — 成否は出力マーカー (`** TEST SUCCEEDED **` の存在 / `** TEST FAILED **` の不在) で判定する (ルール 1)。Bash timeout は 600000 (ルール 16)
6. CLAUDE.md 改訂後に `/usr/bin/grep -n "ViewInspector\|0\.10\.3\|archive" CLAUDE.md` で自己矛盾を確認 (ルール 45)

## スコープ外

- Quick / Nimble の strict pin (証拠がないため今回は見送り。必要になれば別 issue)
- `drafts/` サブディレクトリの新設 (issue 先行を徹底する決定により不要)
- `gh` を使った「対応 issue が closed か」の検証 (#84 の plan で意図的に見送った判断を踏襲。ネットワーク依存を checker に持ち込まない)
- 本番アプリコードの変更 (この PR は開発ループ側のゲートのみ)

## 関連

- PR #156 (#78/#149/#84 バンドル) — 4 件の起点
- PR #150 (#73) — ViewInspector 0.10.2 → 0.10.3 の patch 差で a11y テスト 2 件が反転した実例
- PR #146 (#143) — `rescue LoadError` ガードによる silent green の実測 (ルール 27)
- CLAUDE.md ルール 7 / 8 / 9 / 20 / 22 / 24 / 27 / 36 / 40 / 44 / 45
