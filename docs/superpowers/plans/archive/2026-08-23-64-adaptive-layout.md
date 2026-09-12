# Issue #64: 固定 frame レイアウトの SE / iPad / Dynamic Type 対応 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** トップ画面の固定サイズレイアウト (葉 GIF の固定 frame/padding、CircleButton の固定同心円) を画面サイズ比率 + Dynamic Type 追従に変換し、SE での重なり・iPad での余白過大・AX5 での「START→S…」省略 (実測バグ) を解消する。

**Architecture:** サイズ計算を純粋 struct `TimerLayoutMetrics` (GeometryReader の content size → 葉サイズ/padding) に切り出してユニットテスト可能にする。CircleButton は `@ScaledMetric(relativeTo: .title)` で円ごと拡大 (上限 210pt)、内側 3 円は外円比率で導出。TimerView は GeometryReader で metrics を注入する。

**Tech Stack:** SwiftUI (`@ScaledMetric` / `GeometryReader`)、XCTest (新規テスト。Quick/Nimble は既存分のみ)、`bin/add-to-target.rb` (pbxproj 登録)。

**Spec:** チャット内設計 (2026-08-23 承認、bounded path のため spec ファイルなし)。要点: (1) ボタンは円ごと拡大・上限キャップ + minimumScaleFactor を保険に、(2) 葉は比率ベース + clamp で SE/iPad 両対応 (sizeClass 分岐は不要 — clamp 上限が iPad のバルーン化を防ぐ)、(3) サイズ計算は純粋関数化して TDD、(4) タイマー数字 (#58 対応済み)・背景色・StatChip・設定画面は触らない。

## Global Constraints

- ビルド/テストは毎回 `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置。成否は出力マーカーで判定 (`** TEST SUCCEEDED **` の存在 + `** TEST FAILED **` の不在)。CLAUDE.md ルール 1。
- `make unit-tests` を subagent に実行させる時は Bash timeout 600000 (10 分)。ルール 16。
- 新規 Swift ファイル追加後は `make sort` を最終 commit 前に実行、`make precheck` で orphan 検出。ルール 28。
- default branch は **master**。ルール 37。
- SwiftLint: 新規コードは `.isEmpty` を使う (empty_count)。ルール 35。
- 既存の見た目の基準: 参照 content 高さ (iPhone 17 ≒ 760pt) で scale = 1.0 となり現行の 90/200/350pt を維持する。フラッグシップの見た目を変えないことが回帰基準。

---

### Task 1: ブランチ作成 + plan commit

**Files:**
- Create: `docs/superpowers/plans/2026-08-23-64-adaptive-layout.md` (このファイル)

**Interfaces:**
- Produces: ブランチ `feature/64-adaptive-layout` (以降の全タスクの作業ブランチ)

- [ ] **Step 1: master 最新化とブランチ作成**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git checkout master && git pull --ff-only && git checkout -b feature/64-adaptive-layout
```

- [ ] **Step 2: plan doc を最初の commit にする (ルール 22)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add docs/superpowers/plans/2026-08-23-64-adaptive-layout.md && git commit -m "docs(plan): #64 固定 frame レイアウトの SE/iPad/Dynamic Type 対応計画"
```

---

### Task 2: TimerLayoutMetrics (純粋ロジック + TDD)

**Files:**
- Create: `app/LeafTimer/View/TimerLayoutMetrics.swift`
- Test: `app/LeafTimerTests/AdaptiveLayoutTests.swift` (新規)

**Interfaces:**
- Consumes: `LeafPattern` enum (`app/LeafTimer/ViewModel/TimerViewModel+extensions.swift:170`, case は `.small` / `.mid` / `.big`)
- Produces: `TimerLayoutMetrics(contentSize: CGSize)` / `.scale: CGFloat` / `.leafSize(for: LeafPattern) -> CGFloat` / `.leafBottomPadding(for: LeafPattern) -> CGFloat` / `.leafLeadingPadding(for: LeafPattern) -> CGFloat` / `.leafTrailingPadding(for: LeafPattern) -> CGFloat`。Task 4 の TimerView がこの signature で消費する。

- [ ] **Step 1: 新規 2 ファイルを空で作成し pbxproj に登録**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && touch LeafTimer/View/TimerLayoutMetrics.swift LeafTimerTests/AdaptiveLayoutTests.swift && ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/View/TimerLayoutMetrics.swift LeafTimer LeafTimer/View && ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/AdaptiveLayoutTests.swift LeafTimerTests LeafTimerTests
```

- [ ] **Step 2: 失敗するテストを書く**

`app/LeafTimerTests/AdaptiveLayoutTests.swift`:

```swift
import XCTest

@testable import LeafTimer

/// Issue #64: 固定 frame → 画面比率レイアウトの純粋ロジック検証。
final class AdaptiveLayoutTests: XCTestCase {
    // 参照サイズ (iPhone 17 の content 領域近似) では現行の固定値を維持する (回帰基準)
    func testReferenceSizeKeepsLegacyValues() {
        let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 390, height: 760))

        XCTAssertEqual(metrics.scale, 1.0, accuracy: 0.001)
        XCTAssertEqual(metrics.leafSize(for: .small), 90, accuracy: 0.5)
        XCTAssertEqual(metrics.leafSize(for: .mid), 200, accuracy: 0.5)
        XCTAssertEqual(metrics.leafSize(for: .big), 350, accuracy: 0.5)
        XCTAssertEqual(metrics.leafBottomPadding(for: .big), 300, accuracy: 0.5)
        XCTAssertEqual(metrics.leafTrailingPadding(for: .small), 22, accuracy: 0.5)
        XCTAssertEqual(metrics.leafLeadingPadding(for: .mid), 11, accuracy: 0.5)
    }

    // SE (content 高さ ≒ 600pt) では縮小され、big 葉 + bottom padding が画面内に収まる
    func testSmallDeviceScalesDownAndFits() {
        let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 375, height: 600))

        XCTAssertEqual(metrics.scale, 600.0 / 760.0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(
            metrics.leafSize(for: .big) + metrics.leafBottomPadding(for: .big), 600
        )
    }

    // iPad (content 高さ ≒ 1110pt) は上限 1.35 でキャップされバルーン化しない
    func testLargeDeviceIsCapped() {
        let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 820, height: 1110))

        XCTAssertEqual(metrics.scale, 1.35, accuracy: 0.001)
        XCTAssertEqual(metrics.leafSize(for: .big), 350 * 1.35, accuracy: 0.5)
    }

    // 極端に小さい入力 (回転直後の 0 サイズ等) でも下限 0.55 でクランプされる
    func testTinySizeClampsToLowerBound() {
        let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 320, height: 100))

        XCTAssertEqual(metrics.scale, 0.55, accuracy: 0.001)
    }
}
```

- [ ] **Step 3: テストが FAIL することを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tail -30
```

Expected: コンパイルエラー (`cannot find 'TimerLayoutMetrics' in scope`)。`** TEST SUCCEEDED **` が出ないこと。

- [ ] **Step 4: 最小実装を書く**

`app/LeafTimer/View/TimerLayoutMetrics.swift`:

```swift
import CoreGraphics

/// Issue #64: トップ画面の葉レイアウトを画面サイズ比率で計算する純粋ロジック。
/// View から分離し、SE / iPad の各サイズをユニットテスト可能にする。
struct TimerLayoutMetrics: Equatable {
    /// iPhone 17 で GeometryReader が返す content 高さの近似。ここで scale = 1.0 になり
    /// 現行の固定値 (90/200/350pt) が維持される。
    static let referenceContentHeight: CGFloat = 760
    /// 下限は SE 系の視認性、上限は iPad でのバルーン化防止。
    static let scaleRange: ClosedRange<CGFloat> = 0.55...1.35

    let scale: CGFloat

    init(contentSize: CGSize) {
        let rawScale = contentSize.height / Self.referenceContentHeight
        scale = min(max(rawScale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
    }

    func leafSize(for pattern: LeafPattern) -> CGFloat {
        switch pattern {
        case .small: 90 * scale
        case .mid: 200 * scale
        case .big: 350 * scale
        }
    }

    func leafBottomPadding(for pattern: LeafPattern) -> CGFloat {
        switch pattern {
        case .small: 105 * scale
        case .mid: 150 * scale
        case .big: 300 * scale
        }
    }

    func leafLeadingPadding(for pattern: LeafPattern) -> CGFloat {
        switch pattern {
        case .mid: 11 * scale
        default: 0
        }
    }

    func leafTrailingPadding(for pattern: LeafPattern) -> CGFloat {
        switch pattern {
        case .small: 22 * scale
        default: 0
        }
    }
}
```

- [ ] **Step 5: テストが PASS することを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` なし。

- [ ] **Step 6: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/View/TimerLayoutMetrics.swift app/LeafTimerTests/AdaptiveLayoutTests.swift app/LeafTimer.xcodeproj/project.pbxproj && git commit -m "feat: #64 TimerLayoutMetrics — 葉レイアウトの画面比率計算を純粋ロジック化"
```

---

### Task 3: CircleButton の Dynamic Type 対応 (円ごと拡大 + 上限)

**Files:**
- Modify: `app/LeafTimer/View/Elements/CircleButton.swift` (全体)
- Test: `app/LeafTimerTests/AdaptiveLayoutTests.swift` (テストケース追加)

**Interfaces:**
- Consumes: `TimerViewModel.getColor1()〜getColor4()` / `getButtonState()` (既存、変更なし)
- Produces: `CircleButton.resolvedDiameter(scaled: CGFloat) -> CGFloat` (static、上限キャップの純粋関数)。View の外部 API (`CircleButton(viewModel:)`) は不変なので TimerView 側の変更は不要。

- [ ] **Step 1: 失敗するテストを追加**

`app/LeafTimerTests/AdaptiveLayoutTests.swift` の class 内に追加:

```swift
    // AX5 で @ScaledMetric が拡大した直径は 210pt でキャップされる
    func testCircleButtonDiameterIsCapped() {
        XCTAssertEqual(CircleButton.resolvedDiameter(scaled: 150), 150)
        XCTAssertEqual(CircleButton.resolvedDiameter(scaled: 320), 210)
    }
```

- [ ] **Step 2: テストが FAIL することを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tail -30
```

Expected: コンパイルエラー (`type 'CircleButton' has no member 'resolvedDiameter'`)。

- [ ] **Step 3: CircleButton を書き換える**

`app/LeafTimer/View/Elements/CircleButton.swift` の `struct CircleButton` を以下に置き換え (Preview はそのまま):

```swift
struct CircleButton: View {
    @ObservedObject var viewModel: TimerViewModel

    /// Issue #64: AX5 で文言が「S…」に省略される対策。文字だけでなく円ごと
    /// Dynamic Type に追従させる (#58 のタイマー数字と同じ ScaledMetric + 上限方式)。
    @ScaledMetric(relativeTo: .title) private var scaledDiameter: CGFloat = 150

    static let maxDiameter: CGFloat = 210

    static func resolvedDiameter(scaled: CGFloat) -> CGFloat {
        min(scaled, maxDiameter)
    }

    var body: some View {
        let outer = Self.resolvedDiameter(scaled: scaledDiameter)
        Circle()
            .fill(viewModel.getColor1())
            .frame(width: outer, height: outer, alignment: .center)
            .overlay(
                Circle()
                    .fill(viewModel.getColor2())
                    .frame(width: outer * 140 / 150, height: outer * 140 / 150, alignment: .center)
                    .overlay(
                        Circle()
                            .fill(viewModel.getColor3())
                            .frame(width: outer * 120 / 150, height: outer * 120 / 150, alignment: .center)
                            .overlay(
                                Circle()
                                    .fill(viewModel.getColor4())
                                    .frame(width: outer * 105 / 150, height: outer * 105 / 150, alignment: .center)
                                    .overlay(
                                        Text(viewModel.getButtonState())
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                            .frame(width: outer * 105 / 150 * 0.95)
                                    )
                            )
                    )
            ).shadow(color: .gray, radius: 1, x: 0, y: 1)
    }
}
```

設計意図: 内側 3 円は外円比率 (140/150 等) で導出するので直径 1 本だけが可変。`minimumScaleFactor(0.6)` は円が上限 210pt に達した後も文字が拡大し続けた場合と、長いローカライズ文言 (`button.start` / `button.stop` の翻訳) の保険。`.frame(width:)` で内円幅に制約しないと minimumScaleFactor が発火しない。

- [ ] **Step 4: テストが PASS することを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make unit-tests 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` なし。

- [ ] **Step 5: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/View/Elements/CircleButton.swift app/LeafTimerTests/AdaptiveLayoutTests.swift && git commit -m "fix: #64 CircleButton を Dynamic Type で円ごと拡大 (上限 210pt) — AX5 の START 省略を解消"
```

---

### Task 4: TimerView の葉レイアウトを GeometryReader + metrics に置き換え

**Files:**
- Modify: `app/LeafTimer/View/TimerView.swift:62-95` (`timerContent` の ZStack 周辺) と末尾の DEBUG enum 付近

**Interfaces:**
- Consumes: `TimerLayoutMetrics` (Task 2 の signature)、`DebugInitialScreen` (既存パターンの参照実装、`TimerView.swift:195`)
- Produces: DEBUG 起動引数 `-LeafPattern=small|mid|big` (Task 5 の Simulator 検証が使用)

- [ ] **Step 1: `timerContent` を GeometryReader 化する**

**必ず先に `TimerView.swift` 全体を Read してから編集すること。** 以下のコードブロック内の `// ← 既存の…` コメントは「現行ファイルの該当行 (97–176 行の VStack と modifier チェーン) をそのまま残す」という編集指示であり、**このコメントを literal に貼り付けて既存行を消してはならない**。

`TimerView.swift` の `private var timerContent` を以下に置き換える。変更点は (a) `NavigationStack` 直下に `GeometryReader`、(b) 葉の VStack を `leafLayer(metrics:)` に抽出、(c) 固定値を metrics 参照に変更、の 3 点。2 つ目の VStack (タイマー数字・ボタン・StatChip) と `.navigationTitle` 以降の modifier チェーンは**一切変更しない** (ZStack に付いたまま移動もしない):

```swift
    private var timerContent: some View {
        NavigationStack {
            GeometryReader { geometry in
                let metrics = TimerLayoutMetrics(contentSize: geometry.size)
                ZStack {
                    timerViewModel.getBackgroundColor(colorScheme: colorScheme)
                        .ignoresSafeArea(.all)

                    leafLayer(metrics: metrics)

                    VStack {
                        // ← 既存の Text(timerViewModel.getDisplayedTime()) 〜 StatChip の
                        //    VStack 全体をそのまま維持 (変更なし)
                    }
                    .navigationTitle(NSLocalizedString("timer.title", comment: "Timer navigation title"))
                    // ← 以降の .toolbar / .onAppear / .fullScreenCover も既存のまま
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    /// Issue #64: 葉の固定 frame/padding を TimerLayoutMetrics の比率値に置き換えた層。
    @ViewBuilder
    private func leafLayer(metrics: TimerLayoutMetrics) -> some View {
        let pattern: LeafPattern? = {
            if timerViewModel.breakState { return .big }
#if DEBUG
            if let forced = DebugLeafPattern.requested { return forced }
#endif
            return timerViewModel.getLeafPattern()
        }()

        if let pattern {
            let gifName = switch pattern {
            case .small: "leaf1"
            case .mid: "leaf2"
            case .big: "leaf3"
            }
            GIFView(gifName: gifName)
                .frame(
                    width: metrics.leafSize(for: pattern),
                    height: metrics.leafSize(for: pattern),
                    alignment: .center
                )
                .padding(.leading, metrics.leafLeadingPadding(for: pattern))
                .padding(.trailing, metrics.leafTrailingPadding(for: pattern))
                .padding(.bottom, metrics.leafBottomPadding(for: pattern))
        }
    }
```

注意: 現行コードは break 時に leaf3 を work の big と同一の frame/padding で表示している (`TimerView.swift:70-72` と `:89-93` が同値)。`leafLayer` はこの同値性を `pattern = .big` への正規化で表現しており、見た目の変更はない。

- [ ] **Step 2: DEBUG 起動引数 `-LeafPattern=` フックを追加**

`TimerView.swift` 末尾、既存の `DebugInitialScreen` enum の直後に追加:

```swift
/// Issue #64: 葉パターンは進捗依存で simctl から tap 操作できないため、
/// レイアウト検証用に起動引数で強制する。DebugInitialScreen と同じ発想。
enum DebugLeafPattern {
    static let requested: LeafPattern? = {
        let value = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("-LeafPattern=") }?
            .replacingOccurrences(of: "-LeafPattern=", with: "")
        switch value {
        case "small": return .small
        case "mid": return .mid
        case "big": return .big
        default: return nil
        }
    }()
}
```

(`DebugInitialScreen` と同じ `#if DEBUG` ブロック内に置く。)

- [ ] **Step 3: 全ユニットテスト + precheck が通ることを確認**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` / `Error 6x` なし。`TimerViewSpec.swift:42` の active なテスト (`navigationStack()` の存在確認) は GeometryReader 挿入後も通るはず — 通らなければ inspector パスを `navigationStack()` のままに保てているか確認する (xit のテストは触らない)。

- [ ] **Step 4: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer/View/TimerView.swift && git commit -m "fix: #64 葉レイアウトを GeometryReader + TimerLayoutMetrics の比率ベースに変更"
```

---

### Task 5: Simulator 目視検証 (SE / iPhone 17 / iPad × 標準 / AX5)

**Files:**
- なし (検証のみ。スクショは scratchpad に保存し SendUserFile で共有 — PR にローカルパス画像は埋め込めない、ルール 25)

**Interfaces:**
- Consumes: Task 4 の `-LeafPattern=big` 起動引数、`jp.ema.LeafTimer` bundle ID

検証マトリクス: 3 端末 (iPhone SE (3rd generation) / iPhone 17 / iPad (A16)) × 2 文字サイズ (標準 / AX5) × 葉パターン big (最も崩れやすい: 350pt + padding 300)。small / mid は iPhone SE + AX5 のみ追加確認。色は本 PR で触らないため light 外観のみ (背景 4 状態検証は対象外)。break 状態のレイアウトは big と同値 (Task 4 Step 1 の注意書き参照) のため独立検証しない。

- [ ] **Step 1: Simulator 向けビルドと .app パス取得 (ルール 30)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" build 2>&1 | tail -5 && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -showBuildSettings 2>/dev/null | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //'
```

Expected: `** BUILD SUCCEEDED **` + `.../Debug-iphonesimulator` のパス。

- [ ] **Step 2: 各端末で install → onboarding バイパス → 起動 → スクショ**

**重要 (ルール 23):** この環境の Bash は foreground `sleep` が**ブロックされる** (「無効な場合がある」ではない)。`sleep` をコマンドチェーンに一切入れないこと。起動→スクショの待ち時間は「launch までのチェーン」と「screenshot」を**別々の Bash 呼び出し**に分けることで確保する (ツール呼び出しのラウンドトリップ自体が settle time になる)。

**重要 (ルール 5):** 以下の `<SIM>` / `<APP>` / `<scratchpad>` は実行時に**絶対パス・literal な実名に展開して**コマンドに埋め込むこと (`<APP>` = Step 1 で得た `BUILT_PRODUCTS_DIR` + `/LeafTimer.app`、`<scratchpad>` = セッションの scratchpad ディレクトリ)。シェル変数のまま流用しない。

端末ごと (`<SIM>` を "iPhone SE (3rd generation)" / "iPhone 17" / "iPad (A16)" に差し替え) — **Bash 呼び出し 1** (標準文字サイズは iOS デフォルトの `large`。`medium` ではない):

```bash
xcrun simctl boot "<SIM>" ; xcrun simctl install "<SIM>" "<APP>" && xcrun simctl spawn "<SIM>" defaults write jp.ema.LeafTimer hasSeenOnboarding -bool true && xcrun simctl ui "<SIM>" appearance light && xcrun simctl ui "<SIM>" content_size large && xcrun simctl launch "<SIM>" jp.ema.LeafTimer -LeafPattern=big
```

**Bash 呼び出し 2** (別呼び出しにすることが待ち時間):

```bash
xcrun simctl io "<SIM>" screenshot "<scratchpad>/64-<device>-default-big.png"
```

続けて AX5 — **Bash 呼び出し 3**:

```bash
xcrun simctl ui "<SIM>" content_size accessibility-extra-extra-extra-large && xcrun simctl terminate "<SIM>" jp.ema.LeafTimer ; xcrun simctl launch "<SIM>" jp.ema.LeafTimer -LeafPattern=big
```

**Bash 呼び出し 4**:

```bash
xcrun simctl io "<SIM>" screenshot "<scratchpad>/64-<device>-ax5-big.png"
```

追加検証 (SE のみ):
- small / mid パターン: `-LeafPattern=small` / `-LeafPattern=mid` で AX5 のまま同様に撮影。
- **日本語ロケール × AX5** (ルール 31 の「×ロケール」検証。`.title` の AX5 拡大 ≒ 58pt に対し「スタート」4 文字は minimumScaleFactor 0.6 でギリギリのため、ここが truncation の最尤点):

```bash
xcrun simctl terminate "<SIM>" jp.ema.LeafTimer ; xcrun simctl launch "<SIM>" jp.ema.LeafTimer -LeafPattern=big -AppleLanguages "(ja)"
```

→ 別呼び出しで `64-se-ax5-ja-big.png` を撮影。

- [ ] **Step 3: 判定基準で目視確認し、スクショを SendUserFile でユーザーに共有**

判定基準 (全スクショ共通):
1. START/STOP 文言が省略されていない (AX5 で「S…」にならない — バグの直接検証)
2. 葉 GIF・タイマー数字・ボタン・StatChip が相互に重ならない
3. SE: 葉が画面からはみ出さない / iPad: 葉とボタンが極端に小さく見えない (scale 1.35 で拡大されている)
4. ボタンのタップ領域が視覚的に円と一致 (円からのはみ出しなし)

NG があれば Task 2 の定数 (referenceContentHeight / scaleRange / maxDiameter) を調整して Task 5 を再実行。調整は必ずユニットテストの期待値も同時に更新して commit する。

---

### Task 6: 仕上げ (make tests + PR)

**Files:**
- なし

- [ ] **Step 1: フルチェックを実行 (ルール 28: sort/precheck 含む)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **` あり、`** TEST FAILED **` / `Error 6x` / `No rule to make target` なし。`make sort` が pbxproj を変更した場合は追加 commit。

- [ ] **Step 2: 既存 PR の確認 (ルール 21) と push**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch && gh pr list --state all --head feature/64-adaptive-layout && git push -u origin feature/64-adaptive-layout
```

- [ ] **Step 3: superpowers:finishing-a-development-branch を起動して PR 作成〜merge**

PR 本文の要点: AX5 実測バグ (START→S…) の before/after、TimerLayoutMetrics の設計意図 (参照 760pt / clamp 0.55–1.35)、検証マトリクス結果。スクショはユーザーがブラウザで添付 (ルール 25)。CI 待ちは `gh run watch <run-id> --interval 30` (ルール 23)、merge は `gh pr checks <PR> && gh pr merge <PR> --merge` の同一チェーン (ルール 24)。
