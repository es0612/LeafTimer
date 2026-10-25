# #188 段 1: 葉を START ボタンに固定する Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** どの画面サイズ・文字サイズでも、葉 (small / mid / big) が START ボタンに埋もれないようにする。

**Architecture:** 葉を `TimerView` の `ZStack` (画面中央基準) から外し、START ボタンの `.background(alignment: .top)` に移して、ボタンの上端に固定する。重なりの深さは「ボタン直径 × 20/150」とし、計算は `TimerLayoutMetrics` に置いてユニットテストする。mid / big は固定すると上に伸びるので、上端が今と同じ高さになるまで縮める。

**Tech Stack:** SwiftUI, XCTest (`AdaptiveLayoutTests`)

**Spec:** 独立した spec doc は無い。2026-10-25 のセッションのチャットで合意した内容を下にまとめる (issue #188 の 2026-10-25 コメントも参照)。

- 原因 (実測): 葉は `ZStack` の中で画面中央を基準に、ボタンは `VStack` の流れで、別々に置かれている。Dynamic Type を上げるとボタン (`@ScaledMetric`、150→最大 210pt) だけが大きくなって動き、葉が埋もれる。iPhone 17 Pro の dark では、xxxL で半分ほど埋もれ、AX-L で完全に隠れた
- 重なり: 固定 20pt (オーナーが試作の 0 / 10 / 20pt から選んだ)。直径 150pt に対する比率で持つ (Claude の判断)
- mid / big: ボタンに固定して縮め、上端を今 (標準文字サイズ) と同じ高さに保つ (オーナーの選択)。試作のスクショ (iPhone 17 Pro・標準・3x) から実測して mid 200→140pt、big 350→290pt
- 試作: `spike/188-leaf-anchor` ブランチ (`-LeafOverlap=<pt>` の起動引数)。本実装には使わない
- 比較ページ: https://claude.ai/artifact/UMy2QPnJqVdT5HMVtosbuJ

## Global Constraints

- 対象外: 配色・トンマナ・dark での葉の見え方・起動画面 (`splashIcon`) は #188 の段 2。GIF 素材 (`leaf1〜3.gif`) は変えない。ストアスクショの撮り直しは #164 と同じ回にする
- small のサイズ (90pt) と small の trailing padding (22pt) は変えない
- 重なりの比率: `leafOverlapRatio = 20.0 / 150.0`
- mid の leading padding: 11pt → 8pt (サイズの縮小 140/200 に合わせる)
- `-LeafPattern=small|mid|big` / `-BreakState` の DEBUG フックは残す
- Simulator は、このセッションで作った `leaftimer-188-*` だけを使う。起動済みの共有 Simulator (`5BEEC6A1-…` 等) は別 session (OtetsudaiCoin) が UI テストで使っているので触らない
- ビルド/テストは `cd /Users/shinya/workspace/claude/LeafTimer/app && make tests` (Bash timeout 600000)。成否は `** TEST SUCCEEDED **` の存在と `** TEST FAILED **` の不在で判定する

## Review Focus

1. **時刻の数字が木の手前に描かれること** — 葉を Button の background に移すと、VStack で後ろにある Button の background が Text より手前に描かれる (試作ではコロンが幹に隠れた)。今と同じく数字が手前に来ること → Task 2 Step 1 の `.zIndex(1)` と、Task 3 の big のスクショで確認
2. **葉が重なった部分を押しても START が反応すること** — 葉の frame はボタンより大きく、上 20pt ほど重なる → Task 2 Step 1 の `.allowsHitTesting(false)` と、Task 3 Step 3 のタップ確認
3. **VoiceOver が葉を別の要素として読まないこと** — Button の background に入れたことで、ボタンの読み上げが変わらないこと → Task 2 Step 1 の `.accessibilityHidden(true)`。テストは無く、コードレビューだけで確かめる
4. **SE で big の木がナビゲーションバーに潜らないこと** — 固定すると木の上端はボタン位置で決まる。SE (content 高さ ≒ 600pt) でも上端がタイトルより下にあること → Task 3 の SE × big のスクショ
5. **iPad (scale 1.35 で上限) で big の木が画面からはみ出さないこと** → Task 3 で iPad 13" を 1 枚撮る

---

### Task 1: `TimerLayoutMetrics` に重なりの計算を足し、mid / big を縮める

**Files:**
- Modify: `app/LeafTimer/View/TimerLayoutMetrics.swift`
- Test: `app/LeafTimerTests/AdaptiveLayoutTests.swift`

**Interfaces:**
- Produces:
  - `static let leafOverlapRatio: CGFloat` (= `20.0 / 150.0`)
  - `func leafOffsetY(for pattern: LeafPattern, buttonDiameter: CGFloat) -> CGFloat` — 戻り値は `buttonDiameter * leafOverlapRatio - leafSize(for: pattern)`。葉の frame の上端をボタンの上端に合わせたあと、この値だけ y 方向に動かすと、葉の下端がボタンの上端から `buttonDiameter * leafOverlapRatio` だけ下に来る
  - `leafSize(for:)`: small 90 / mid **140** / big **290** (× scale)
  - `leafLeadingPadding(for:)`: mid **8** (× scale)、ほかは 0
  - `leafTrailingPadding(for:)`: 変更なし (small 22 × scale)
  - `leafBottomPadding(for:)` は Task 2 で **削除** する (葉の位置はボタン基準になるので使わない。Task 1 の時点では `TimerView` がまだ呼ぶので残す)

- [ ] **Step 1: テストを書き換える (RED)**

`testReferenceSizeKeepsLegacyValues` を次の名前と assertion にする (`leafBottomPadding` の行は消す)。

```swift
// 参照サイズでは small は従来値、mid/big は #188 でボタンに固定したぶん縮めた値
func testReferenceSizeValues() {
    let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 390, height: 760))

    XCTAssertEqual(metrics.scale, 1.0, accuracy: 0.001)
    XCTAssertEqual(metrics.leafSize(for: .small), 90, accuracy: 0.5)
    XCTAssertEqual(metrics.leafSize(for: .mid), 140, accuracy: 0.5)
    XCTAssertEqual(metrics.leafSize(for: .big), 290, accuracy: 0.5)
    XCTAssertEqual(metrics.leafTrailingPadding(for: .small), 22, accuracy: 0.5)
    XCTAssertEqual(metrics.leafLeadingPadding(for: .mid), 8, accuracy: 0.5)
}
```

`testSmallDeviceScalesDownAndFits` は `leafBottomPadding` を使っているので、次に置き換える。

```swift
// SE (content 高さ ≒ 600pt) では葉が縮小される
func testSmallDeviceScalesDown() {
    let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 375, height: 600))

    XCTAssertEqual(metrics.scale, 600.0 / 760.0, accuracy: 0.001)
    XCTAssertEqual(metrics.leafSize(for: .big), 290 * 600.0 / 760.0, accuracy: 0.5)
}
```

`testLargeDeviceIsCapped` の big の期待値を `350 * 1.35` → `290 * 1.35` にする。

新しいテストを 2 つ足す。

```swift
// Issue #188: 葉の下端はボタンの上端から直径 × 20/150 だけ下に来る (標準の直径 150 で 20pt)
func testLeafOverlapsButtonByRatioOfDiameter() {
    let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 390, height: 760))

    XCTAssertEqual(TimerLayoutMetrics.leafOverlapRatio, 20.0 / 150.0, accuracy: 0.0001)
    XCTAssertEqual(metrics.leafOffsetY(for: .small, buttonDiameter: 150), 20 - 90, accuracy: 0.5)
}

// Issue #188: Dynamic Type でボタンが大きくなる (上限 210) と、重なりも同じ比率で深くなる
func testLeafOverlapFollowsButtonDiameter() {
    let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 375, height: 600))

    XCTAssertEqual(metrics.leafOffsetY(for: .big, buttonDiameter: 210), 28 - 290 * 600.0 / 760.0, accuracy: 0.5)
    XCTAssertEqual(metrics.leafOffsetY(for: .mid, buttonDiameter: 150), 20 - 140 * 600.0 / 760.0, accuracy: 0.5)
}
```

- [ ] **Step 2: 重なりの計算だけ足して、値の RED を確認する**

`TimerLayoutMetrics` に `leafOverlapRatio` と `leafOffsetY(for:buttonDiameter:)` だけを足す。サイズ・padding は今の値 (mid 200 / big 350 / leading 11) のまま、`leafBottomPadding(for:)` も残す。`leafOffsetY` の doc comment に Issue #188 と「下端がボタン上端から直径 × 比率だけ下」を書く。

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | grep -E "AdaptiveLayoutTests.*(passed|failed)"`
Expected: 失敗はちょうど次の 4 件。

- `testReferenceSizeValues` (mid 200≠140、big 350≠290、leading 11≠8)
- `testSmallDeviceScalesDown`
- `testLargeDeviceIsCapped`
- `testLeafOverlapFollowsButtonDiameter`

`testLeafOverlapsButtonByRatioOfDiameter` は small を使うので、この時点で通る。最初の実行で出力の行の形を 1 回見てから grep を信じる (ルール 3)。これと違ったら止めて報告する

- [ ] **Step 3: mid / big を縮める (GREEN)**

Interfaces のとおり、mid 140 / big 290 / mid の leading 8 にする。`leafBottomPadding(for:)` は Task 2 で消す (まだ `TimerView.swift:208` が呼んでいる)。

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | grep -c "AdaptiveLayoutTests.*passed"`
Expected: `9` (今の 7 件 + 新しい 2 件)。あわせて `** TEST SUCCEEDED **` があり、`** TEST FAILED **` が無いこと

- [ ] **Step 4: mutation で新しいテストが効くことを確かめる**

| 壊し方 | 落ちるべきテスト |
|---|---|
| `leafOverlapRatio` を `10.0 / 150.0` にする | `testLeafOverlapsButtonByRatioOfDiameter` / `testLeafOverlapFollowsButtonDiameter` |
| `leafOffsetY` で `buttonDiameter` の代わりに `150` を使う | `testLeafOverlapFollowsButtonDiameter` |

壊すたびに `make unit-tests` を走らせて、表のテストが落ちることを確かめてから元に戻す (big を 350 に戻す mutation は Step 2 の RED で済んでいる)

- [ ] **Step 5: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add app/LeafTimer/View/TimerLayoutMetrics.swift app/LeafTimerTests/AdaptiveLayoutTests.swift
git commit -m "feat(#188): TimerLayoutMetrics に葉の重なりの計算を足し、mid/big を縮める"
```

### Task 2: `TimerView` で葉をボタンに固定する

**Files:**
- Modify: `app/LeafTimer/View/TimerView.swift` (`timerContent` の ZStack / VStack、`leafLayer(metrics:)`)

**Interfaces:**
- Consumes: Task 1 の `leafSize(for:)` / `leafLeadingPadding(for:)` / `leafTrailingPadding(for:)` / `leafOffsetY(for:buttonDiameter:)`
- Produces: `private func leafLayer(metrics: TimerLayoutMetrics, buttonDiameter: CGFloat) -> some View`

- [ ] **Step 1: 配置を変える**

- `ZStack` 直下の `leafLayer(metrics: metrics)` を消す
- START の `Button` に、`.buttonStyle(.plain)` の直後で `.background(alignment: .top) { … }` を付ける。中身は `GeometryReader` で直径 (= `proxy.size.height`) を取り、`leafLayer(metrics:buttonDiameter:)` を横中央に置く (`.frame(width: proxy.size.width)`)
- `leafLayer` は `.padding(.bottom, …)` をやめ、`.offset(y: metrics.leafOffsetY(for: pattern, buttonDiameter: buttonDiameter))` で置く。`.allowsHitTesting(false)` と `.accessibilityHidden(true)` を付ける (Review Focus 2・3)
- 時刻の `Text` に `.zIndex(1)` を付け、木より手前に描く (Review Focus 1)。コメントに Issue #188 と理由を書く
- `TimerLayoutMetrics.leafBottomPadding(for:)` を消す (呼び出し元が無くなる)

- [ ] **Step 2: ビルドとテストを通す**

Run: `cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **` があり、`** TEST FAILED **` が無い

- [ ] **Step 3: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer
git add app/LeafTimer/View/TimerLayoutMetrics.swift app/LeafTimer/View/TimerView.swift
git commit -m "fix(#188): 葉を START ボタンの上端に固定し、文字サイズを上げても埋もれないようにする"
```

### Task 3: スクショで確かめ、PR を作る

**Files:**
- Move: `docs/superpowers/plans/2026-10-25-issue-188-leaf-anchor.md` → `docs/superpowers/plans/archive/`

- [ ] **Step 1: 撮る**

専用の Simulator (`xcrun simctl create leaftimer-188-<機種> "<機種>"`) で、SE (3rd generation) / iPhone 17 Pro / iPhone 17 Pro Max について撮る。組み合わせは light・dark × 文字サイズ 3 つ (large / extra-extra-extra-large / accessibility-large) × 葉 4 状態 (`-LeafPattern=small` / `mid` / `big` / `-BreakState`)。ほかに iPad 13" の dark・large・big を 1 枚撮る。起動引数は `-hasSeenOnboarding YES`、Reduce Motion は on (GIF を止める)。手順は skill `leaftimer-simulator-verification`

- [ ] **Step 2: 判定する**

どのスクショでも次の 4 つを満たすこと。

- 葉がボタンに隠れていない
- 時刻の数字が木の手前にある
- 木の上端がナビゲーションバーより下にある
- iPad で木がはみ出していない

iPhone 17 Pro の dark・large では、mid / big の木の上端が試作の「今」(mid 976px / big 576px) から ±30px 以内にあること。外れたら止めて報告する

- [ ] **Step 3: START のタップを確かめる**

iPhone 17 Pro の dark・large・small で、葉が重なっているボタン上端から 10pt 下を `cliclick` でタップし、表示が STOP に変わること

- [ ] **Step 4: 比較ページを更新してオーナーに見せる**

https://claude.ai/artifact/UMy2QPnJqVdT5HMVtosbuJ に「今」と「修正後」を並べる

- [ ] **Step 5: plan を archive へ移し、PR を作る**

`git mv` で plan を `archive/` に移して commit する。push の前に `gh pr list --state all --head feature/188-leaf-anchor` を確認する。PR 本文は `Refs #188` にする (段 2 が残るので close しない)。スクショは SendUserFile でオーナーに渡す
