import XCTest

@testable import LeafTimer

// Issue #54: suspend 中のフェーズ跨ぎを壁時計から一括計算する純粋ロジックの検証。
final class PhaseReconcilerTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_000_000)
    private let work = 25 * 60
    private let brk = 5 * 60

    // 跨ぎゼロ: endDate 前に復帰 → 残り秒のみ更新 (冪等性の要)
    func testNoCrossingUpdatesRemainingOnly() {
        let end = base.addingTimeInterval(600)
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: work, breakDuration: brk,
            now: base.addingTimeInterval(100)
        )
        XCTAssertEqual(result, PhaseReconcileResult(
            breakState: false, completedWorkCount: 0,
            remainingSeconds: 500, newEndDate: end
        ))
    }

    // work 終了を 1 回跨ぐ → break 中・work 1 完了
    func testCrossingOneWorkEnd() {
        let end = base.addingTimeInterval(600)
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: work, breakDuration: brk,
            now: end.addingTimeInterval(10)
        )
        XCTAssertEqual(result.breakState, true)
        XCTAssertEqual(result.completedWorkCount, 1)
        XCTAssertEqual(result.remainingSeconds, brk - 10)
        XCTAssertEqual(result.newEndDate, end.addingTimeInterval(TimeInterval(brk)))
    }

    // ちょうど境界 (now == endDate) は「跨いだ」扱い
    func testExactBoundaryCountsAsCrossed() {
        let end = base.addingTimeInterval(600)
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: work, breakDuration: brk,
            now: end
        )
        XCTAssertEqual(result.breakState, true)
        XCTAssertEqual(result.completedWorkCount, 1)
        XCTAssertEqual(result.remainingSeconds, brk)
    }

    // 複数往復: work 終了 → break 終了 → work 終了 (work 2 完了、break 中)
    func testCrossingMultiplePhases() {
        let end = base.addingTimeInterval(600)
        // 跨ぐ量: 600 (今の work 残り) + brk + work + 30 秒
        let now = base.addingTimeInterval(TimeInterval(600 + brk + work + 30))
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: work, breakDuration: brk,
            now: now
        )
        XCTAssertEqual(result.breakState, true)
        XCTAssertEqual(result.completedWorkCount, 2)
        XCTAssertEqual(result.remainingSeconds, brk - 30)
    }

    // break 起点: break 終了を跨いでも work は完了しない
    func testCrossingFromBreakDoesNotCountWork() {
        let end = base.addingTimeInterval(100)
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: true,
            workDuration: work, breakDuration: brk,
            now: end.addingTimeInterval(20)
        )
        XCTAssertEqual(result.breakState, false)
        XCTAssertEqual(result.completedWorkCount, 0)
        XCTAssertEqual(result.remainingSeconds, work - 20)
    }

    // duration が両方 0 (異常系) は無限ループせず現状維持で返す
    func testZeroDurationsReturnSafely() {
        let end = base
        let result = PhaseReconciler.reconcile(
            endDate: end, breakState: false,
            workDuration: 0, breakDuration: 0,
            now: base.addingTimeInterval(50)
        )
        XCTAssertEqual(result.completedWorkCount, 0)
        XCTAssertEqual(result.remainingSeconds, 0)
    }
}
