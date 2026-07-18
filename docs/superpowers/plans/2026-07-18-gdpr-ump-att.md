# GDPR 同意 (UMP) + ATT 対応 Implementation Plan (Issue #57)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AdMob の広告リクエスト前に UMP (User Messaging Platform) の同意フローと ATT (App Tracking Transparency) の許可リクエストを挟み、EEA/UK ポリシー違反による配信停止リスクを解消する。

**Architecture:** UMP / ATT / GADMobileAds への依存を 3 つの protocol (`ConsentService` / `TrackingAuthorizer` / `AdsStarter`) で抽象化し、「同意取得 → ATT → 広告 SDK start」の順序制御を `AdsBootstrapper` (ObservableObject) に集約する。`AppDelegate` は起動時の即時 `GADMobileAds.start` をやめて bootstrap 呼び出しに置き換え、`AdsView` は `isAdsStarted` が立つまでバナーを生成しない。オーケストレーション部分は spy 注入で unit test し、SDK ラッパーは薄く保ってビルド + Simulator 手動検証で担保する。

**Tech Stack:** Swift / SwiftUI, GoogleUserMessagingPlatform 3.0.0 (CocoaPods 導入済み・未使用), Google-Mobile-Ads-SDK 11.13.0, AppTrackingTransparency (iOS 17.0 deployment target なので availability ガード不要), XCTest (新規テストは Quick/Nimble ではなく XCTest — 直近の OnboardingGateTests 等の流儀に合わせる)

## Global Constraints

- default branch は `master`。作業ブランチは `feature/57-gdpr-ump-att`
- テスト実行: `cd app && make unit-tests` (Bash timeout は 600000ms を明示)。成否は exit code ではなく出力の `** TEST SUCCEEDED **` / `** TEST FAILED **` マーカーで判定する (zsh のため `${PIPESTATUS[0]}` は使用禁止。`| tail` する時は `set -o pipefail` を前置)
- 新規 Swift ファイルは必ず `cd app && ruby bin/add-to-target.rb LeafTimer.xcodeproj <file> <target> <group>` で target に attach する (attach 漏れは silent にビルド対象外になる)
- 新規ファイル追加後は `cd app && make precheck` で orphan 検証、最終 commit 前に `cd app && make sort && git status` を実行する
- `print()` 追加禁止 (既存 `AdsView.swift:9` の print は Issue #70 スコープなので触らない)
- 旧 `SettingView.swift` は dead code (Issue #72 で削除予定)。本 plan では**修正対象にしない** (AdsView の呼び出し側 API を変えないことで無修正のままコンパイルを維持する)
- **UMP 3.0.0 Swift API 名 (実装時に確定済み)**: 実ビルドで確定した名称は plan 初版の想定 (`ConsentRequestParameters` 等) とも UMP prefix 版とも異なる第 3 の形だった。コンパイラの rename 診断 (`'UMPRequestParameters' has been renamed to 'RequestParameters'`) で判明:

| 実際の Swift 名 (v3.0.0) | 備考 |
| --- | --- |
| `ConsentInformation.shared` | plan 想定どおり |
| `ConsentForm.loadAndPresentIfRequired(from:completionHandler:)` | plan 想定どおり |
| `RequestParameters` | 初版想定 `ConsentRequestParameters` ではない |
| `DebugSettings` | 初版想定 `ConsentDebugSettings` ではない |
| `DebugGeography.EEA` | plan 想定どおり |

---

## Task 0: Plan commit

**Files:**
- Create: `docs/superpowers/plans/2026-07-18-gdpr-ump-att.md` (this file)

- [ ] **Step 1: ブランチ確認と plan の commit**

```bash
git checkout feature/57-gdpr-ump-att
git add docs/superpowers/plans/2026-07-18-gdpr-ump-att.md
git commit -m "docs(plan): #57 GDPR 同意 (UMP) + ATT 対応の実装 plan"
```

---

## Task 1: AdsBootstrapper — 同意→ATT→広告開始のオーケストレータ (TDD)

**Files:**
- Create: `app/LeafTimer/Components/AdsBootstrapper.swift`
- Test: `app/LeafTimerTests/AdsBootstrapperTests.swift`

**Interfaces:**
- Produces (後続 Task が依存する契約):
  - `protocol ConsentService { var canRequestAds: Bool { get }; func gatherConsent(from viewController: UIViewController?, completion: @escaping (Error?) -> Void) }`
  - `protocol TrackingAuthorizer { func requestAuthorization(completion: @escaping () -> Void) }`
  - `protocol AdsStarter { func startAds() }`
  - `final class AdsBootstrapper: ObservableObject` — `static let shared`, `@Published private(set) var isAdsStarted: Bool`, `init(consentService:trackingAuthorizer:adsStarter:)`, `func bootstrap(from viewController: UIViewController?, completion: (() -> Void)?)`
  - `AdsBootstrapper.shared` は Task 2 で作る実装クラス (`UMPConsentService()` / `ATTAuthorizer()` / `GADAdsStarter()`) をデフォルト引数で使う。**Task 1 の時点では実装クラスが未定なので、`shared` とデフォルト引数は Task 2 で追加する** (Task 1 では明示 init のみ)

- [ ] **Step 1: 失敗するテストを書く**

`app/LeafTimerTests/AdsBootstrapperTests.swift` を以下の内容で作成:

```swift
import XCTest
@testable import LeafTimer

final class AdsBootstrapperTests: XCTestCase {
    private var consent: SpyConsentService!
    private var tracking: SpyTrackingAuthorizer!
    private var ads: SpyAdsStarter!
    private var bootstrapper: AdsBootstrapper!

    override func setUp() {
        super.setUp()
        callOrder = []
        consent = SpyConsentService()
        tracking = SpyTrackingAuthorizer()
        ads = SpyAdsStarter()
        consent.onGather = { [weak self] in self?.callOrder.append("consent") }
        tracking.onRequest = { [weak self] in self?.callOrder.append("att") }
        ads.onStart = { [weak self] in self?.callOrder.append("start") }
        bootstrapper = AdsBootstrapper(
            consentService: consent,
            trackingAuthorizer: tracking,
            adsStarter: ads
        )
    }

    func testBootstrapRunsConsentThenATTThenStartsAds() {
        bootstrapper.bootstrap(from: nil, completion: nil)

        XCTAssertEqual(consent.gatherCallCount, 1)
        XCTAssertEqual(tracking.requestCallCount, 1)
        XCTAssertEqual(ads.startCallCount, 1)
        // 順序: 同意 → ATT → start
        XCTAssertEqual(callOrder, ["consent", "att", "start"])
        XCTAssertTrue(bootstrapper.isAdsStarted)
    }

    func testBootstrapDoesNotStartAdsWhenConsentDisallows() {
        consent.canRequestAds = false

        bootstrapper.bootstrap(from: nil, completion: nil)

        XCTAssertEqual(ads.startCallCount, 0)
        XCTAssertFalse(bootstrapper.isAdsStarted)
        // ATT の許可リクエスト自体は同意結果と独立に 1 回行う
        XCTAssertEqual(tracking.requestCallCount, 1)
    }

    func testBootstrapStartsAdsOnConsentErrorIfCachedConsentAllows() {
        // UMP はネットワークエラー時でも前回セッションの同意が cache されており
        // canRequestAds が true のままのことがある。その場合は start して良い
        consent.gatherError = DummyError.network
        consent.canRequestAds = true

        bootstrapper.bootstrap(from: nil, completion: nil)

        XCTAssertEqual(ads.startCallCount, 1)
        XCTAssertTrue(bootstrapper.isAdsStarted)
    }

    func testBootstrapIsIdempotent() {
        bootstrapper.bootstrap(from: nil, completion: nil)
        bootstrapper.bootstrap(from: nil, completion: nil)

        XCTAssertEqual(consent.gatherCallCount, 1)
        XCTAssertEqual(ads.startCallCount, 1)
    }

    func testBootstrapCallsCompletionAfterFlow() {
        var completed = false
        bootstrapper.bootstrap(from: nil) { completed = true }
        XCTAssertTrue(completed)
    }

    // MARK: - Spies

    private var callOrder: [String] = []

    private enum DummyError: Error { case network }

    private final class SpyConsentService: ConsentService {
        var canRequestAds = true
        var gatherError: Error?
        private(set) var gatherCallCount = 0
        var onGather: (() -> Void)?

        func gatherConsent(
            from viewController: UIViewController?,
            completion: @escaping (Error?) -> Void
        ) {
            gatherCallCount += 1
            onGather?()
            completion(gatherError)
        }
    }

    private final class SpyTrackingAuthorizer: TrackingAuthorizer {
        private(set) var requestCallCount = 0
        var onRequest: (() -> Void)?

        func requestAuthorization(completion: @escaping () -> Void) {
            requestCallCount += 1
            onRequest?()
            completion()
        }
    }

    private final class SpyAdsStarter: AdsStarter {
        private(set) var startCallCount = 0
        var onStart: (() -> Void)?

        func startAds() {
            startCallCount += 1
            onStart?()
        }
    }
}
```

- [ ] **Step 2: テストファイルを test target に attach**

```bash
cd app && ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimerTests/AdsBootstrapperTests.swift LeafTimerTests LeafTimerTests
```

- [ ] **Step 3: RED を確認する**

Run (timeout 600000ms):

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tail -40
```

Expected: **ビルド失敗** — `cannot find type 'ConsentService' in scope` (および `AdsBootstrapper` 未定義)。コンパイルエラーによる RED であることを確認する。テストが誤って green なら手を止めて原因調査。

- [ ] **Step 4: 最小実装を書く**

`app/LeafTimer/Components/AdsBootstrapper.swift` を以下の内容で作成:

```swift
import Foundation
import UIKit

protocol ConsentService {
    var canRequestAds: Bool { get }
    func gatherConsent(
        from viewController: UIViewController?,
        completion: @escaping (Error?) -> Void
    )
}

protocol TrackingAuthorizer {
    func requestAuthorization(completion: @escaping () -> Void)
}

protocol AdsStarter {
    func startAds()
}

/// 広告表示前の同意フローを統括する。
/// 順序: UMP 同意取得 → ATT 許可リクエスト → (同意 OK なら) GADMobileAds start
final class AdsBootstrapper: ObservableObject {
    @Published private(set) var isAdsStarted = false

    private let consentService: ConsentService
    private let trackingAuthorizer: TrackingAuthorizer
    private let adsStarter: AdsStarter
    private var isBootstrapping = false

    init(
        consentService: ConsentService,
        trackingAuthorizer: TrackingAuthorizer,
        adsStarter: AdsStarter
    ) {
        self.consentService = consentService
        self.trackingAuthorizer = trackingAuthorizer
        self.adsStarter = adsStarter
    }

    func bootstrap(from viewController: UIViewController?, completion: (() -> Void)?) {
        guard !isAdsStarted, !isBootstrapping else {
            completion?()
            return
        }
        isBootstrapping = true

        // UMP がエラーを返しても前回セッションの cached 同意で
        // canRequestAds が立ち得るため、エラーでもフローは継続する
        consentService.gatherConsent(from: viewController) { [weak self] _ in
            self?.trackingAuthorizer.requestAuthorization {
                guard let self else { return }
                self.isBootstrapping = false
                if self.consentService.canRequestAds {
                    self.adsStarter.startAds()
                    self.isAdsStarted = true
                }
                completion?()
            }
        }
    }
}
```

- [ ] **Step 5: 実装ファイルを app target に attach**

```bash
cd app && ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/Components/AdsBootstrapper.swift LeafTimer LeafTimer/Components
```

- [ ] **Step 6: GREEN を確認する**

Run (timeout 600000ms):

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **` が出力に含まれる。AdsBootstrapperTests の 5 テスト全て pass。

- [ ] **Step 7: Commit**

```bash
git add app/LeafTimer/Components/AdsBootstrapper.swift app/LeafTimerTests/AdsBootstrapperTests.swift app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "feat(ads): #57 同意フローを統括する AdsBootstrapper を TDD で追加"
```

---

## Task 2: SDK ラッパー実装 (UMPConsentService / ATTAuthorizer / GADAdsStarter)

**Files:**
- Create: `app/LeafTimer/Components/AdsConsentServices.swift`
- Modify: `app/LeafTimer/Components/AdsBootstrapper.swift` (shared singleton + デフォルト引数の追加)

**Interfaces:**
- Consumes: Task 1 の `ConsentService` / `TrackingAuthorizer` / `AdsStarter` protocol
- Produces: `UMPConsentService` / `ATTAuthorizer` / `GADAdsStarter` (いずれも上記 protocol 準拠)、`AdsBootstrapper.shared` (Task 3 の AppDelegate / AdsView が使用)

薄い SDK ラッパーで分岐ロジックを持たないため unit test は書かない (オーケストレーションは Task 1 でテスト済み)。ビルド成立 + Task 4 の Simulator 手動検証で担保する。

- [ ] **Step 1: SDK ラッパーを書く**

`app/LeafTimer/Components/AdsConsentServices.swift` を以下の内容で作成 (ビルドエラー時は Global Constraints の API 対応表で旧名称に置換):

```swift
import AppTrackingTransparency
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// UMP (User Messaging Platform) による GDPR 同意取得。
/// EEA/UK 以外の地域では form 提示不要と判定され、そのまま completion が呼ばれる。
final class UMPConsentService: ConsentService {
    var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    func gatherConsent(
        from viewController: UIViewController?,
        completion: @escaping (Error?) -> Void
    ) {
        let parameters = ConsentRequestParameters()
        #if DEBUG
        // Simulator 検証用: launch argument で EEA 地域を強制する
        if ProcessInfo.processInfo.arguments.contains("-UMPDebugGeographyEEA") {
            let debugSettings = ConsentDebugSettings()
            debugSettings.geography = .EEA
            parameters.debugSettings = debugSettings
        }
        #endif

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { updateError in
            if let updateError {
                completion(updateError)
                return
            }
            DispatchQueue.main.async {
                ConsentForm.loadAndPresentIfRequired(from: viewController) { formError in
                    completion(formError)
                }
            }
        }
    }
}

/// ATT (App Tracking Transparency) の許可リクエスト。
/// 既に許可/拒否済み (.notDetermined 以外) の場合はダイアログなしで即 completion が呼ばれる。
final class ATTAuthorizer: TrackingAuthorizer {
    func requestAuthorization(completion: @escaping () -> Void) {
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

final class GADAdsStarter: AdsStarter {
    func startAds() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }
}
```

注意: `import UserMessagingPlatform` がモジュール名。`No such module` になる場合は `import GoogleUserMessagingPlatform` を試す。

- [ ] **Step 2: AdsBootstrapper に shared とデフォルト引数を追加**

`app/LeafTimer/Components/AdsBootstrapper.swift` の `init` を以下に置換し、`static let shared` を追加:

```swift
    static let shared = AdsBootstrapper()

    init(
        consentService: ConsentService = UMPConsentService(),
        trackingAuthorizer: TrackingAuthorizer = ATTAuthorizer(),
        adsStarter: AdsStarter = GADAdsStarter()
    ) {
        self.consentService = consentService
        self.trackingAuthorizer = trackingAuthorizer
        self.adsStarter = adsStarter
    }
```

- [ ] **Step 3: ファイルを app target に attach**

```bash
cd app && ruby bin/add-to-target.rb LeafTimer.xcodeproj LeafTimer/Components/AdsConsentServices.swift LeafTimer LeafTimer/Components
```

- [ ] **Step 4: ビルド + 既存テスト green を確認**

Run (timeout 600000ms):

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **`。API 名エラーが出た場合は Global Constraints の対応表で置換して再実行。

- [ ] **Step 5: Commit**

```bash
git add app/LeafTimer/Components/AdsConsentServices.swift app/LeafTimer/Components/AdsBootstrapper.swift app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "feat(ads): #57 UMP/ATT/GADMobileAds の実装ラッパーを追加"
```

---

## Task 3: 配線 — AppDelegate / AdsView / Info.plist / InfoPlist.strings

**Files:**
- Modify: `app/LeafTimer/App/AppDelegate.swift:20` (即時 start の除去) / `:39` 直後 (bootstrap 呼び出し)
- Modify: `app/LeafTimer/View/AdsView.swift` (同意完了までバナー非生成)
- Modify: `app/LeafTimer/Info.plist` (`NSUserTrackingUsageDescription` + `GADDelayAppMeasurementInit`)
- Modify: `app/LeafTimer/App/ja.lproj/InfoPlist.strings` / `app/LeafTimer/App/en.lproj/InfoPlist.strings`

**Interfaces:**
- Consumes: `AdsBootstrapper.shared` / `.isAdsStarted` / `.bootstrap(from:completion:)` (Task 1–2)

- [ ] **Step 1: AppDelegate から即時 start を除去し bootstrap に置換**

`app/LeafTimer/App/AppDelegate.swift` の

```swift
        FirebaseApp.configure()
        GADMobileAds.sharedInstance().start(completionHandler: nil)
```

を

```swift
        FirebaseApp.configure()
        // GADMobileAds の start は UMP 同意 + ATT 完了後に AdsBootstrapper が行う (#57)
```

に置換し、`window?.makeKeyAndVisible()` の直後に以下を追加:

```swift
        // 同意フォーム/ATT ダイアログの提示は app active 後である必要があるため
        // 起動処理完了後の main queue で開始する
        DispatchQueue.main.async { [weak self] in
            AdsBootstrapper.shared.bootstrap(
                from: self?.window?.rootViewController,
                completion: nil
            )
        }
```

- [ ] **Step 2: AdsView を同意ゲート付きに変更**

`app/LeafTimer/View/AdsView.swift` の `AdsView` struct 全体 (1〜21 行目の `import` 2 行と `AdsView`) を以下に置換する。呼び出し側 (`EnhancedSettingView.swift:94` と dead な `SettingView.swift:74`) は `AdsView().frame(...)` のままなので**変更不要**:

```swift
import GoogleMobileAds
import SwiftUI

struct AdsView: View {
    @ObservedObject private var adsBootstrapper = AdsBootstrapper.shared

    var body: some View {
        if adsBootstrapper.isAdsStarted {
            AdsBannerView()
        } else {
            Color.clear
        }
    }
}

private struct AdsBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)

        banner.adUnitID = KeyManager().getAdUnitID()
        // iOS 17対応: windowSceneから適切なrootViewControllerを取得
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            banner.rootViewController = windowScene.windows.first?.rootViewController
        }

        let request = GADRequest()
        banner.load(request)
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
```

注意: 既存の `print(banner.adUnitID)` (旧 9 行目) はこの置換で消える。これは Issue #70 スコープの print 削除を先取りするのではなく、`AdsBannerView` へ移設する際に持ち込まない判断 (新規コードに print 追加禁止)。ファイル末尾の dead な `ContentView` / `ContentView_Previews` は触らない (Issue #72 スコープ)。

- [ ] **Step 3: Info.plist にキーを追加**

`app/LeafTimer/Info.plist` の `<key>GADIsAdManagerApp</key>` の手前に以下を追加:

```xml
	<key>GADDelayAppMeasurementInit</key>
	<true/>
```

`<key>LSRequiresIPhoneOS</key>` の手前 (アルファベット順で N の位置) に以下を追加:

```xml
	<key>NSUserTrackingUsageDescription</key>
	<string>This identifier will be used to deliver personalized ads to you.</string>
```

`GADDelayAppMeasurementInit` は「明示的に start を呼ぶまで SDK の計測初期化を遅延させる」キーで、start を同意後に遅延させた本対応とセットで必要。

- [ ] **Step 4: InfoPlist.strings に ATT 文言のローカライズを追加**

`app/LeafTimer/App/ja.lproj/InfoPlist.strings` の末尾に追加:

```text
"NSUserTrackingUsageDescription" = "広告配信を最適化するために識別子を使用します。";
```

`app/LeafTimer/App/en.lproj/InfoPlist.strings` の末尾に追加:

```text
"NSUserTrackingUsageDescription" = "This identifier will be used to deliver personalized ads to you.";
```

- [ ] **Step 5: ビルド + 既存テスト green を確認**

Run (timeout 600000ms):

```bash
cd app && set -o pipefail && make unit-tests 2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **`。既存の View 系 Spec (TimerViewSpec / ModernSettingViewSpec 等) が AdsView の構造変更で fail していないことを確認する。fail した場合は当該 Spec が `AdsView` の内部構造 (UIViewRepresentable であること) に依存していないか読み、依存があればテスト側を `AdsView` の新構造に合わせて更新する。

- [ ] **Step 6: Commit**

```bash
git add app/LeafTimer/App/AppDelegate.swift app/LeafTimer/View/AdsView.swift app/LeafTimer/Info.plist app/LeafTimer/App/ja.lproj/InfoPlist.strings app/LeafTimer/App/en.lproj/InfoPlist.strings
git commit -m "feat(ads): #57 起動時の広告初期化を同意フロー完了後に遅延し ATT 文言を追加"
```

---

## Task 4: Simulator 手動検証 + 仕上げ (sort / precheck / PR)

**Files:**
- Modify (必要時のみ): 検証で発覚した不具合の修正

- [ ] **Step 1: EEA 同意フォームの表示を Simulator で検証**

REQUIRED SUB-SKILL: `ios-simulator-app-verification` の boot/build/install/launch/screenshot サイクルに従う。検証ポイント:

1. `-UMPDebugGeographyEEA` launch argument 付きで起動 → **UMP 同意フォームが表示される**こと (スクリーンショット取得)
2. フォームで同意 → **ATT ダイアログが表示される**こと (スクリーンショット取得)。Simulator の 設定 > プライバシーとセキュリティ > トラッキング で「Appからのトラッキング要求を許可」が OFF だと ATT ダイアログは表示されずに即 denied になる。その場合は ON にしてアプリを削除→再インストールして再検証
3. 同意完了後、設定画面 (歯車アイコン) を開いて**バナー枠が表示される**こと
4. launch argument なし (日本地域) で削除→再インストール起動 → 同意フォームは出ず、ATT ダイアログのみ表示され、バナーが従来どおり表示されること
5. 再起動 2 回目以降はダイアログ類が一切出ないこと (UMP cache + ATT 決定済み)

再検証時の同意リセットはアプリ削除 (`xcrun simctl uninstall <SIM> <bundle-id>`) で行う。

- [ ] **Step 2: 最終チェック**

```bash
cd app && make precheck && make sort && git status
```

Expected: precheck pass (新規 2 ファイルの orphan なし)、sort 後の `git status` で差分が出た場合は pbxproj を追加 commit:

```bash
git add app/LeafTimer.xcodeproj/project.pbxproj
git commit -m "chore: #57 project.pbxproj の children グループをソート"
```

- [ ] **Step 3: フルテスト**

Run (timeout 600000ms):

```bash
cd app && set -o pipefail && make tests 2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **` (precheck / sort / lint / unit-tests 全て pass)

- [ ] **Step 4: Push + PR 作成**

```bash
git fetch && gh pr list --state all --head feature/57-gdpr-ump-att
git push -u origin feature/57-gdpr-ump-att
```

PR 本文には Step 1 のスクリーンショット用の空セクション (「## スクリーンショット」見出しのみ) を用意し、画像ファイルは `SendUserFile` でユーザーに渡してブラウザからドラッグ&ドロップしてもらう (`gh` はローカル画像を embed できない)。

```bash
gh pr create --title "feat(ads): #57 AdMob の GDPR 同意 (UMP) と ATT を実装" --body "..."
```

PR 本文に含める内容: Issue #57 へのリンク (`Closes #57`)、同意フローの順序図 (UMP → ATT → start)、検証した 5 パターン (EEA 同意 / EEA 拒否は今回未検証なら明記 / 日本 / 2 回目起動 / バナー表示)、スクリーンショット空セクション。

---

## Self-Review 結果

- **Spec coverage**: Issue #57 の対応方針案 3 点 (UMP consent form 提示 / requestTrackingAuthorization / NSUserTrackingUsageDescription) は Task 2 (UMP/ATT 実装)・Task 3 (plist + 文言) でカバー。追加で GADDelayAppMeasurementInit と起動時 start の遅延 (Task 3)、EEA/非 EEA の Simulator 検証 (Task 4) を含めた
- **Placeholder scan**: コード全文・コマンド・期待出力を全ステップに記載済み。PR body のみ「...」だが構成要素は列挙済み
- **Type consistency**: `ConsentService.gatherConsent(from: UIViewController?, ...)` — Task 1 のテスト/実装、Task 2 の UMPConsentService、Task 3 の AppDelegate 呼び出しで optional VC を渡す設計に統一 (テストから `nil` を渡せるようにするため optional)
- **Path 実在確認**: `app/bin/add-to-target.rb` / `app/Makefile` の `precheck`・`sort`・`unit-tests`・`tests` ターゲット / `AppDelegate.swift:20` / `AdsView.swift` / `Info.plist` / `ja.lproj/en.lproj InfoPlist.strings` / `EnhancedSettingView.swift:94` は全て Read/Glob で確認済み。UMP の Swift API 名のみ Pods が read deny のため未確認 — fallback 表で吸収する
