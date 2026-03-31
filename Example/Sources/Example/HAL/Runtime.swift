import CPicoSDK

private nonisolated(unsafe) var scheduledActions = RingBuffer<16, () -> Void>()
private nonisolated(unsafe) var isDrainingScheduled = false

public enum Runtime {
    @discardableResult
    public static func schedule(_ action: @escaping () -> Void) -> Bool {
        scheduledActions.push(action)
    }

    public static func run(_ frame: () -> Void) -> Never {
        while true {
            service()
            frame()
        }
    }

    @inline(__always)
    public static func service() {
        pollGPIOIRQs()
        drainScheduledActions()
        tight_loop_contents()
    }

    public static func sleep(ms: UInt32) {
        let deadline = nowMs() &+ ms
        while Int32(bitPattern: nowMs() &- deadline) < 0 {
            service()
            sleep_us(250)
        }
    }

    public static func sleep(us: UInt32) {
        let deadline = time_us_64() &+ UInt64(us)
        while Int64(bitPattern: time_us_64() &- deadline) < 0 {
            service()
            sleep_us(100)
        }
    }
}

private func drainScheduledActions() {
    if isDrainingScheduled {
        return
    }

    isDrainingScheduled = true
    defer { isDrainingScheduled = false }

    while let action = scheduledActions.pop() {
        action()
    }
}
