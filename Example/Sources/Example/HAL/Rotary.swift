import CPicoSDK

public enum RotaryChange: Sendable {
    case clockwise
    case counterClockwise
    case switchPressed
    case switchReleased
}

public typealias RotaryHandler = (RotaryChange) -> Void

public final class RotaryEncoder<let count: Int> {
    private let clkPin: GPIOPin
    private let dtPin: GPIOPin
    private let switchPin: GPIOPin?
    private var lastStatus: UInt8
    private var lastSwitchState: Bool
    private var lastSwitchEventMs: UInt32 = 0
    private var handlers = InlineArray<count, RotaryHandler?>(repeating: nil)

    public init(clk: UInt32, dt: UInt32, sw: UInt32? = nil) {
        self.clkPin = GPIOPin(clk)
        self.dtPin = GPIOPin(dt)
        self.switchPin = sw.map(GPIOPin.init)

        clkPin.setDirection(output: false)
        dtPin.setDirection(output: false)
        clkPin.setPull(.up)
        dtPin.setPull(.up)

        if let switchPin {
            switchPin.setDirection(output: false)
            switchPin.setPull(.up)
            lastSwitchState = switchPin.read()
        } else {
            lastSwitchState = true
        }

        lastStatus = RotaryEncoder.makeStatus(dt: dtPin.read(), clk: clkPin.read())

        _ = gpioOnIRQ(pin: clk, edge: .both) { [self] _, _ in
            rotaryChange()
        }
        _ = gpioOnIRQ(pin: dt, edge: .both) { [self] _, _ in
            rotaryChange()
        }
        if let sw {
            _ = gpioOnIRQ(pin: sw, edge: .both) { [self] _, _ in
                switchChanged()
            }
        }
    }

    public func addHandler(_ handler: @escaping RotaryHandler) {
        var index = 0
        while index < count {
            if handlers[index] == nil {
                handlers[index] = handler
                return
            }
            index += 1
        }

        print("RotaryEncoder: no free handler slots")
    }

    private static func makeStatus(dt: Bool, clk: Bool) -> UInt8 {
        (dt ? 1 : 0) << 1 | (clk ? 1 : 0)
    }

    private func rotaryChange() {
        let newStatus = RotaryEncoder.makeStatus(dt: dtPin.read(), clk: clkPin.read())
        if newStatus == lastStatus {
            return
        }

        let transition = (lastStatus << 2) | newStatus
        switch transition {
        case 0b1110:
            scheduleHandlers(.clockwise)
        case 0b1101:
            scheduleHandlers(.counterClockwise)
        default:
            break
        }
        lastStatus = newStatus
    }

    private func switchChanged() {
        guard let switchPin else {
            return
        }

        let now = nowMs()
        if now &- lastSwitchEventMs < 20 {
            return
        }

        let newState = switchPin.read()
        guard newState != lastSwitchState else {
            return
        }

        lastSwitchState = newState
        lastSwitchEventMs = now
        scheduleHandlers(newState ? .switchReleased : .switchPressed)
    }

    private func scheduleHandlers(_ change: RotaryChange) {
        let scheduled = Runtime.schedule { [self] in
            callHandlers(change)
        }

        if !scheduled {
            print("RotaryEncoder: runtime schedule queue overflow")
        }
    }

    private func callHandlers(_ change: RotaryChange) {
        var index = 0
        while index < count {
            if let handler = handlers[index] {
                handler(change)
            }
            index += 1
        }
    }
}
