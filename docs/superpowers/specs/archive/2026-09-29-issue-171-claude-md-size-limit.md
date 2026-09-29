# #171 CLAUDE.md のサイズ上限を make ターゲットで守る — design

- Issue: #171
- 状態: spec (2026-09-29 のセッションでユーザー合意済みの設計)

## 目的

「学び → CLAUDE.md に 1 行足す」が唯一の受け皿で、引く仕組みが無い。#111 (2026-08-15) で 11.5KB に圧縮した CLAUDE.md が 6 週間で 30,077B に戻った。上限を機械的に守るゲートを置き、超えたら「引く」判断を強制する。

## 物差し

- 導入時: PR 本文に CLAUDE.md のバイト数 before/after (30,077B → 実測値) を書く
- 運用: 導入後 3 回の振り返りで、上限 18,000B 以内に収まっているか (issue #171 の物差し)

## 決定事項

| 論点 | 決定 | 理由 |
| --- | --- | --- |
| 判定単位 | UTF-8 バイト数 | issue の記述 (KB) と一致。日本語 1 文字 = 3B で文字数より安定して増減が見える |
| 上限 | 18,000B | 経緯退避 + 領域分離で届く見込み。残り約 1.5KB を追記余白にし、超えたら引く判断を促す (15KB はルール統合・廃止まで要る可能性が高く、22KB は再肥大が早い) |
| 削り方 | 経緯退避 + 領域分離 | 経緯 (PR 番号・実測値・事故詳細) は archive へ、作業時にだけ要る領域はプロジェクト skill へ |
| 領域の置き場 | `.claude/skills/<name>/SKILL.md` (repo 管理) | description が合えば自動ロードされ、ポインタ行の読み落としに依存しない。docs + ポインタ (B) は読むかどうかが AI 任せ、`app/CLAUDE.md` はほぼ常時ロードされ削減にならない |
| ルール番号 | 振り直さない | CLAUDE.md 外に「ルール N」参照が 279 件 (archive・plan・checker のメッセージ)。移したルールはポインタ行として番号を残す |

## 構成

### 1. チェッカー `claude-md-size-check`

既存 checker と同じ 2 層構成 (ルール 33):

- `app/bin/claude_md_size_check.rb` — 純粋ロジック。`ClaudeMdSizeCheck::LIMIT_BYTES = 18_000`、`result(bytesize:, limit:)` が ok/ng と超過量を返す
- `app/bin/claude-md-size-check.rb` — CLI。既定は repo 直下の `CLAUDE.md`、`ARGV[0]` で fixture パスを差し替え可能 (ルール 8 の (i): 引数を読まないと fixture 検証が vacuous になる)
- `app/bin/test_claude_md_size_check.rb` — minitest
- `app/Makefile` — `claude-md-size-check` ターゲット (test → 本体の順)。`tests` チェーンに追加。同名ファイル・ディレクトリは無いが、既存ターゲットと同じ書式にそろえる

出力:

- 成功: `✅ claude-md-size-check passed (CLAUDE.md 17,xxx / 18,000 bytes)`
- 失敗: `❌ claude-md-size-check failed: CLAUDE.md 30,077 / 18,000 bytes (+12,077)` に続けて直し方 2 行 (経緯は `docs/claude-lessons-archive.md` へ / 作業時だけ要る手順は `.claude/skills/` へ)
- ファイルが無い: fail (exit 1)。vacuous green を塞ぐ

テスト:

- 上限未満・ちょうど上限 (18,000 = ok)・上限 +1 (ng) の境界 3 件
- ファイル無しで exit 1 (CLI)
- ARGV の fixture 差し替えが効くこと (CLI、上限超えの fixture で exit 1)
- mutation: 判定を `<` ↔ `<=` に壊すと境界テストが RED、`LIMIT_BYTES` を変えると境界テストが RED (新規テスト 1 件 : mutation 1 つ以上の対応表を plan に書く)

### 2. 領域分離 (プロジェクト skill 2 本)

| skill | 移すルール | 内容 |
| --- | --- | --- |
| `leaftimer-simulator-verification` | 12, 30, 31, 32, 42 | View の live 参照確認、`.app` のパス取得、背景 4 状態の目視、Dynamic Type / onboarding / ATT / cliclick / 通知バナー / アニメ判定 / スクショ原寸目視、旧ストアスクショとの突き合わせ |
| `leaftimer-xcode-deps` | 26, 27, 28, 29, 43 | CI の明示 install と bundle exec、gem 依存の `rescue LoadError` と CI の silent skip、`make add-file` と pbxproj 構造検査、Package.resolved、テストフレームワーク方針と Podfile 制約 |

- 各 SKILL.md は元ルールの手順を「何をするか」中心で持つ。経緯は archive に置き、skill からは「経緯: `docs/claude-lessons-archive.md` ルール N」と参照する
- CLAUDE.md 側は各ルール番号を 1 行のポインタに置き換える (例: `32. Dynamic Type・onboarding・ATT・スクショ検証 → skill leaftimer-simulator-verification`)
- description は「いつ使うか」で書く (Simulator で画面を確認する時 / Swift ファイル追加・pbxproj・Podfile・Gemfile・CI 依存を触る時)
- ルール 43 の「テストは新規は XCTest、View 構造は ViewInspector」は日常的に効くので、CLAUDE.md に 1 文だけ残し、Podfile 制約の詳細を skill へ移す

### 3. 残るルールの圧縮

- 各行を「何をするか」に絞る。PR 番号・実測値・事故の経緯は `docs/claude-lessons-archive.md` の末尾に `## 2026-09-29 追記: #171 で CLAUDE.md から退避した経緯` 節を作り、ルール番号ごとに移す
- 情報を消さない (移すだけ)。圧縮前の CLAUDE.md の各行の要素が、CLAUDE.md・skill・archive のどこかに残っていることを plan のタスクで突き合わせる

### 4. 整合確認

- ルール 45: 圧縮後、同じ話題を扱う行 (ルール 37 と 44、ルール 14 の例外など) を `/usr/bin/grep` して自己矛盾が無いことを確認
- CLAUDE.md 内のルール間参照 (「ルール 37 と同じ形で」等) が移動後も解決できること
- `make tests` が green で、その出力に `✅ claude-md-size-check passed` 行があること

## やらないこと

- `~/.claude/CLAUDE.md` (グローバル) や `docs/claude-lessons-archive.md` のサイズ制限
- ルールの統合・廃止 (18KB に届かなかった場合のみ、plan 実行中にユーザーへ相談する)
- ルール番号の振り直し

## リスク

- skill の description が合わず自動ロードされない → CLAUDE.md のポインタ行が保険。1 週間運用して、Simulator 検証セッションで skill が使われたかを振り返りで確認する
- 圧縮で手順の要点が落ちる → タスク 3 の突き合わせと final review で確認
