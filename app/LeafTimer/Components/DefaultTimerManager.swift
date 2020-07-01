import Foundation

protocol TimerManager {
    func start(target: TimerViewModel)
    func stop()
    func reset()
}


class DefaultTimerManager: TimerManager {
    private var timer: Timer?

    func start(target: TimerViewModel) {
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: target,
            selector: #selector(target.updateTime),
            userInfo: nil,
            repeats: true)
    }

    func stop() {
        timer?.invalidate()
    }

    func reset() {

    }
}
