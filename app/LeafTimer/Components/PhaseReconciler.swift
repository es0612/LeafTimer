import Foundation

// Issue #54: suspend 中に跨いだフェーズ境界を壁時計から一括計算する。
// 副作用なしの純粋ロジック。now < endDate なら跨ぎゼロで冪等。
struct PhaseReconcileResult: Equatable {
    let breakState: Bool
    let completedWorkCount: Int
    let remainingSeconds: Int
    let newEndDate: Date
}

enum PhaseReconciler {
    static func reconcile(
        endDate: Date,
        breakState: Bool,
        workDuration: Int,
        breakDuration: Int,
        now: Date
    ) -> PhaseReconcileResult {
        guard workDuration + breakDuration > 0 else {
            return PhaseReconcileResult(
                breakState: breakState, completedWorkCount: 0,
                remainingSeconds: 0, newEndDate: endDate
            )
        }

        var end = endDate
        var isBreak = breakState
        var completedWork = 0

        while now >= end {
            if !isBreak {
                completedWork += 1
            }
            isBreak.toggle()
            let nextDuration = isBreak ? breakDuration : workDuration
            end = end.addingTimeInterval(TimeInterval(nextDuration))
        }

        let remaining = max(0, Int(end.timeIntervalSince(now).rounded()))
        return PhaseReconcileResult(
            breakState: isBreak, completedWorkCount: completedWork,
            remainingSeconds: remaining, newEndDate: end
        )
    }
}
