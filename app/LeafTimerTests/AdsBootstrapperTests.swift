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
