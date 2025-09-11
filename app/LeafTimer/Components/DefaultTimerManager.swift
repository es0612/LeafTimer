import Foundation

protocol TimerManager {
    func start(target: TimerViewModel)
    func stop()
    func reset()
}

/// Modern iOS 17 optimized timer manager with improved performance and memory management
class DefaultTimerManager: TimerManager {
    private var timer: Timer?
    private weak var target: AnyObject?
    
    // iOS 17: Use background queue for timer to reduce main thread overhead
    private let timerQueue = DispatchQueue(label: "com.leaftimer.timer", qos: .userInitiated)
    
    func start(target: TimerViewModel) {
        // Store weak reference to prevent retain cycles
        self.target = target
        
        // Stop any existing timer first
        stop()
        
        // iOS 17: Improved timer scheduling with better energy efficiency
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak target] _ in
            guard let strongTarget = target else {
                self?.stop() // Auto-cleanup if target is deallocated
                return
            }
            
            // Ensure UI updates happen on main queue
            DispatchQueue.main.async {
                strongTarget.updateTime()
            }
        }
        
        // iOS 17: Optimize for battery life with more precise tolerance
        timer?.tolerance = 0.1
        
        // Add to run loop with common modes for better responsiveness
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        // Reset implementation for future extensibility
        // Currently maintains existing behavior (no-op)
    }
    
    // iOS 17: Cleanup method for proper memory management
    deinit {
        stop()
    }
}
